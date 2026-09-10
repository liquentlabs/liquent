use crate::command::{Command as LiquentCommand, Executable};
use clap::{CommandFactory, Parser};
use clap_complete::{generate, Shell};

#[derive(Debug, Parser)]
pub struct CompletionsCommand {
    /// Shell to generate completions for (bash, zsh, fish, powershell, elvish)
    #[clap(value_enum)]
    pub shell: Shell,
}

impl Executable for CompletionsCommand {
    fn execute(self) -> Result<(), anyhow::Error> {
        let mut cmd = LiquentCommand::command();
        generate(self.shell, &mut cmd, "liquent-cli", &mut std::io::stdout());
        Ok(())
    }
}
