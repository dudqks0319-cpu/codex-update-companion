import Foundation

public enum StatusBarVisibilityPolicy {
    public static func isVisible(onlyShowWhenCodexRuns: Bool, isCodexRunning: Bool) -> Bool {
        !onlyShowWhenCodexRuns || isCodexRunning
    }
}
