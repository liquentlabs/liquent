from setuptools import setup, find_packages

setup(
    name="liquent-e2e",
    version="0.1.0",
    description="E2E Test Framework for Liquent Node",
    packages=find_packages(),
    install_requires=[
        "web3>=6.0.0",
        "eth-account>=0.13.6",
        "aiohttp>=3.8.0",
        "pyyaml>=6.0",
        "pytest>=7.0.0",
        "pytest-asyncio>=0.21.0",
    ],
    python_requires=">=3.8",
    entry_points={
        "console_scripts": [
            "liquent-e2e=liquent_e2e.main:main",
        ],
    },
)