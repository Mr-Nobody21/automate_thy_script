import os
import sys
import subprocess
import platform
import csv
import requests
import time
import json
import logging
from datetime import datetime
from getpass import getpass
from pathlib import Path

# Initialize logging
logging.basicConfig(level=logging.INFO, format='[%(levelname)s] %(message)s')

# Supported chains and their respective API endpoints and API key env names
CHAIN_CONFIG = {
    'ethereum': {
        'explorer': 'https://api.etherscan.io/api',
        'env_key': 'ETHERSCAN_API_KEY'
    },
    'polygon': {
        'explorer': 'https://api.polygonscan.com/api',
        'env_key': 'POLYGONSCAN_API_KEY'
    },
    'bsc': {
        'explorer': 'https://api.bscscan.com/api',
        'env_key': 'BSCSCAN_API_KEY'
    },
    'base': {
        'explorer': 'https://api.basescan.org/api',
        'env_key': 'BASESCAN_API_KEY'
    },
    'avalanche': {
        'explorer': 'https://api.snowtrace.io/api',
        'env_key': 'AVASCAN_API_KEY'
    },
    'solana': {
        'explorer': None,
        'env_key': 'SOLANA_RPC_URL'
    }
}

CONFIG_FILE = Path.home() / ".multichain_config.json"

def check_or_create_venv():
    logging.info("Checking virtual environment...")
    if not os.path.isdir("venv"):
        logging.info("Creating virtual environment...")
        subprocess.check_call([sys.executable, '-m', 'venv', 'venv'])
        pip_path = "venv/bin/pip" if platform.system() != 'Windows' else "venv\\Scripts\\pip.exe"
        subprocess.check_call([pip_path, 'install', '--upgrade', 'pip'])
        subprocess.check_call([pip_path, 'install', 'requests'])
        logging.info("Virtual environment created.")
    else:
        logging.info("Virtual environment already exists.")

def load_or_create_config():
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    return {}

def save_config(config):
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=4)

def get_api_key(chain, config):
    env_var = CHAIN_CONFIG[chain]['env_key']
    api_key = config.get(env_var)
    if not api_key:
        api_key = getpass(f"Enter API key for {chain} (will be stored locally): ")
        config[env_var] = api_key
        save_config(config)
    return api_key

def fetch_evm_transactions(chain, contract_address, api_key):
    url = CHAIN_CONFIG[chain]['explorer']
    all_txs = []
    page = 1
    offset = 10000
    logging.info(f"Fetching transactions from {chain}...")
    while True:
        params = {
            'module': 'account',
            'action': 'txlist',
            'address': contract_address,
            'startblock': 0,
            'endblock': 99999999,
            'page': page,
            'offset': offset,
            'sort': 'asc',
            'apikey': api_key
        }
        response = requests.get(url, params=params)
        data = response.json()
        if data['status'] != '1' and data['message'] != 'No transactions found':
            logging.error(f"Error fetching transactions for {chain}: {data.get('message', 'Unknown error')}")
            break
        txs = data.get('result', [])
        if not txs:
            break
        all_txs.extend(txs)
        if len(txs) < offset:
            break
        page += 1
        time.sleep(0.2)
    logging.info(f"Fetched {len(all_txs)} transactions for {chain}")
    return all_txs

def fetch_solana_transactions(contract_address, rpc_url):
    logging.info("Fetching Solana transactions...")
    all_txs = []
    before = None
    limit = 1000
    while True:
        body = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getSignaturesForAddress",
            "params": [contract_address, {"limit": limit, "before": before}]
        }
        response = requests.post(rpc_url, json=body)
        data = response.json()
        txs = data.get("result", [])
        if not txs:
            break
        all_txs.extend(txs)
        before = txs[-1]['signature']
        time.sleep(0.2)
    logging.info(f"Fetched {len(all_txs)} transactions for Solana")
    return all_txs

def save_to_csv(filename, transactions, chain):
    os.makedirs("output", exist_ok=True)
    filepath = os.path.join("output", filename)
    with open(filepath, mode='w', newline='', encoding='utf-8') as csvfile:
        if chain != 'solana':
            fieldnames = ['hash', 'blockNumber', 'timeStamp', 'from', 'to', 'value']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for tx in transactions:
                writer.writerow({
                    'hash': tx['hash'],
                    'blockNumber': tx['blockNumber'],
                    'timeStamp': datetime.utcfromtimestamp(int(tx['timeStamp'])).isoformat(),
                    'from': tx['from'],
                    'to': tx['to'],
                    'value': tx['value']
                })
        else:
            fieldnames = ['signature', 'slot']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for tx in transactions:
                writer.writerow({
                    'signature': tx['signature'],
                    'slot': tx['slot']
                })
    logging.info(f"Saved {len(transactions)} transactions to {filepath}")

def main():
    check_or_create_venv()
    config = load_or_create_config()

    contract_address = input("Enter contract address: ")
    chains = input("Enter chains (comma separated: ethereum, polygon, bsc, base, avalanche, solana): ").lower().split(',')

    for chain in chains:
        chain = chain.strip()
        if chain not in CHAIN_CONFIG:
            logging.warning(f"Skipping unknown chain: {chain}")
            continue

        try:
            if chain == 'solana':
                rpc_url = config.get('SOLANA_RPC_URL')
                if not rpc_url:
                    rpc_url = input("Enter Solana RPC URL: ")
                    config['SOLANA_RPC_URL'] = rpc_url
                    save_config(config)
                transactions = fetch_solana_transactions(contract_address, rpc_url)
            else:
                api_key = get_api_key(chain, config)
                transactions = fetch_evm_transactions(chain, contract_address, api_key)
            save_to_csv(f"{chain}_transactions.csv", transactions, chain)
        except Exception as e:
            logging.error(f"Error processing {chain}: {str(e)}")

if __name__ == '__main__':
    main()
