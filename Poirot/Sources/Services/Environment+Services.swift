import SwiftUI

private struct SessionLoaderKey: EnvironmentKey {
    static let defaultValue: any SessionLoading = SessionLoader()
}

private struct ProviderKey: EnvironmentKey {
    static let defaultValue: any ProviderDescribing = ClaudeCodeProvider()
}

private struct TodoLoaderKey: EnvironmentKey {
    static let defaultValue: any TodoLoading = TodoLoader()
}

private struct HistoryLoaderKey: EnvironmentKey {
    static let defaultValue: any HistoryLoading = HistoryLoader()
}

private struct FacetsLoaderKey: EnvironmentKey {
    static let defaultValue: any FacetsLoading = FacetsLoader()
}

private struct FileHistoryLoaderKey: EnvironmentKey {
    static let defaultValue: any FileHistoryLoading = FileHistoryLoader()
}

extension EnvironmentValues {
    var sessionLoader: any SessionLoading {
        get { self[SessionLoaderKey.self] }
        set { self[SessionLoaderKey.self] = newValue }
    }

    var provider: any ProviderDescribing {
        get { self[ProviderKey.self] }
        set { self[ProviderKey.self] = newValue }
    }

    var todoLoader: any TodoLoading {
        get { self[TodoLoaderKey.self] }
        set { self[TodoLoaderKey.self] = newValue }
    }

    var historyLoader: any HistoryLoading {
        get { self[HistoryLoaderKey.self] }
        set { self[HistoryLoaderKey.self] = newValue }
    }

    var facetsLoader: any FacetsLoading {
        get { self[FacetsLoaderKey.self] }
        set { self[FacetsLoaderKey.self] = newValue }
    }

    var fileHistoryLoader: any FileHistoryLoading {
        get { self[FileHistoryLoaderKey.self] }
        set { self[FileHistoryLoaderKey.self] = newValue }
    }
}
