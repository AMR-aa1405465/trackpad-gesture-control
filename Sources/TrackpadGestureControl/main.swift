import Foundation
import GestureCLI

// Composition root: no logic here. All behaviour lives in the engines/commands.
exit(CLIApplication.main(arguments: Array(CommandLine.arguments.dropFirst())))
