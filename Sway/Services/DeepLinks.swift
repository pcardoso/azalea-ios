import Foundation

/// Prescription links from the email: https://app.gowithsway.com/apps/open/CODE (a universal
/// link, so the app opens straight from the email) and sway://prescription/CODE (tried by the
/// web page when the universal link was skipped, e.g. by an in-app browser).
enum DeepLinks {
    static func prescriptionCode(from url: URL) -> String? {
        let segments = url.pathComponents.filter { $0 != "/" }
        let code: String?
        switch url.scheme {
        case "sway" where url.host() == "prescription":
            code = segments.first
        case "https" where segments.count >= 3 && segments[0] == "apps" && segments[1] == "open":
            code = segments[2]
        default:
            code = nil
        }
        let trimmed = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}
