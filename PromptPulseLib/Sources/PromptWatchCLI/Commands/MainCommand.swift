import ArgumentParser
import Foundation
import PromptWatchKit
import PromptWatchDomain

/// Main entry point for the promptwatch CLI
@main
struct MainCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "promptwatch",
        abstract: "Monitor Claude Code CLI instances",
        version: PromptWatchVersion.version,
        subcommands: [
            ProcessCommand.self,
            SessionsCommand.self,
            InspectCommand.self,
        ],
        defaultSubcommand: ProcessCommand.self
    )
}
