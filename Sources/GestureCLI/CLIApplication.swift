import Foundation
import GestureActions
import GestureConfig

/// Wires the command engine together. The only place that lists all commands.
public enum CLIApplication {
    public static func main(arguments: [String]) -> Int32 {
        var args = arguments
        var url = ConfigurationLoader.defaultPath
        if let i = args.firstIndex(of: "--config"), i + 1 < args.count {
            url = URL(fileURLWithPath: args[i + 1])
            args.removeSubrange(i...(i + 1))
        }
        // `debug` (or --debug) turns on gesture/action logging; otherwise the app stays quiet.
        var debug = false
        if args.first == "debug" { debug = true; args.removeFirst() }
        if let i = args.firstIndex(of: "--debug") { debug = true; args.remove(at: i) }
        let store = ConfigurationStore(url: url)
        let factory = ActionFactory.standard()

        let router = CommandRouter()
        let session = GestureSession(store: store, factory: factory, debug: debug)
        let agent = LaunchAgentManager()
        router.defaultCommand = "start"
        router.register(StartCommand(
            session: session,
            agent: agent,
            prompters: [ShortcutPrompter(), LaunchAppPrompter(catalog: AppCatalog()), ClickPrompter()]
        ))
        router.register(RunCommand(session: session))
        router.register(AutostartCommand(manager: agent))
        router.register(MonitorCommand())
        router.register(GesturesCommand())
        router.register(ActionsCommand(factory: factory))
        router.register(BindingsCommand(store: store, factory: factory))
        router.register(DoctorCommand())
        router.register(InitCommand(store: store))
        return router.run(args)
    }
}
