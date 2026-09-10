mod bootstrap;
pub mod config_storage;
pub mod consensus_api;
mod consensus_mempool_handler;
mod https;
mod logger;
mod network;

pub use aptos_mempool::core_mempool::AdmitHandle;
pub use bootstrap::check_bootstrap_config;
use clap::Parser;
pub use laptos::aptos_config::config::NodeConfig;
use std::path::PathBuf;

/// Runs an Liquent validator or fullnode
#[derive(Clone, Debug, Parser)]
#[command(name = "Liquent Node", author, version)]
pub struct LiquentNodeArgs {
    #[arg(long = "liquent_node_config", value_name = "CONFIG", global = true)]
    /// Path to node configuration file (or template for local test mode).
    pub node_config_path: Option<PathBuf>,

    #[arg(long = "relayer_config", value_name = "RELAYER_CONFIG", global = true)]
    /// Path to relayer configuration file (JSON format with URI to RPC URL mappings).
    pub relayer_config_path: Option<PathBuf>,
}
