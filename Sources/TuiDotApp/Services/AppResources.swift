import Foundation

enum AppResources {
    private static let resourceBundleName = "tuidotapp_TuiDotApp.bundle"

    static func url(forResource name: String, withExtension extensionName: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: extensionName) {
            return url
        }
        if let bundle = packagedResourceBundle,
           let url = bundle.url(forResource: name, withExtension: extensionName)
        {
            return url
        }
        return Bundle.module.url(forResource: name, withExtension: extensionName)
    }

    static var swiftPMBundleURL: URL? {
        if let packagedResourceBundle { return packagedResourceBundle.bundleURL }
        let url = Bundle.module.bundleURL
        return url == Bundle.main.bundleURL ? nil : url
    }

    private static var packagedResourceBundle: Bundle? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        return Bundle(url: resources.appendingPathComponent(resourceBundleName, isDirectory: true))
    }
}
