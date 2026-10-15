import Foundation

public enum SyncConfig {
    /// Placeholder container. Create the same id in the CloudKit dashboard
    /// when you turn on the iCloud capability. Local mode never reads this.
    public static let cloudKitContainerIdentifier = "iCloud.com.plantpal.app"
    public static let recordType = "Plant"
    /// Shared with the widget extension once the App Group capability is on.
    /// A free personal team cannot sign that capability, so the store also
    /// keeps a copy in the app's own container.
    public static let appGroupIdentifier = "group.com.plantpal.shared"
}
