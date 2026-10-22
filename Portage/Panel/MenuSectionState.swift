import Foundation

struct MenuSectionState: Codable {
    var moreOptions = false
    var expandedFeatures: Set<String> = []
}
