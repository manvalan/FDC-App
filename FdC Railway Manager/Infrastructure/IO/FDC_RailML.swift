import Foundation

/// A basic RailML parser for railway infrastructure.
/// RailML is an industry standard XML-based format.
class RailMLParser: NSObject, XMLParserDelegate {
    
    private var nodes: [Node] = []
    private var edges: [Edge] = []
    
    private var currentElement = ""
    private var currentAttr: [String: String] = [:]
    
    private var tracks: [[String: String]] = []
    private var currentTrackId: String?
    
    func parse(data: Data) -> (nodes: [Node], edges: [Edge])? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        if parser.parse() {
            return (nodes, edges)
        }
        return nil
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentAttr = attributeDict
        
        switch elementName {
        case "ocp": // Operation Control Point (Station/Node)
            if let id = attributeDict["id"] {
                let name = attributeDict["name"] ?? id
                let type: Node.NodeType = (attributeDict["type"] == "station") ? .station : .interchange
                nodes.append(Node(id: id, name: name, type: type))
            }
            
        case "track":
            currentTrackId = attributeDict["id"]
            
        case "trackBegin", "trackEnd":
            if let trackId = currentTrackId, let ref = attributeDict["ref"] {
                // Simplified topology: we'll create an edge for each track eventually
                // In a real RailML, a track has a begin and end reference
                // For simplicity, we store them as we find them
                tracks.append(["trackId": trackId, "type": elementName, "ref": ref])
            }
            
        case "geoCoord":
            if let latStr = attributeDict["latitude"], let lonStr = attributeDict["longitude"],
               let lat = Double(latStr), let lon = Double(lonStr) {
                // Apply to last node (simplification)
                if !nodes.isEmpty {
                    var last = nodes.removeLast()
                    last.latitude = lat
                    last.longitude = lon
                    nodes.append(last)
                }
            }
            
        default:
            break
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        // Build edges from tracked topology
        var trackBuild: [String: (begin: String?, end: String?)] = [:]
        for t in tracks {
            let id = t["trackId"]!
            let ref = t["ref"]!
            let type = t["type"]!
            
            var existing = trackBuild[id] ?? (nil, nil)
            if type == "trackBegin" { existing.begin = ref }
            else { existing.end = ref }
            trackBuild[id] = existing
        }
        
        for (_, val) in trackBuild {
            if let b = val.begin, let e = val.end {
                edges.append(Edge(from: b, to: e, distance: 1.0, trackType: .regional, maxSpeed: 120))
            }
        }
    }
}
