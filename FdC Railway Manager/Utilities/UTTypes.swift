import UniformTypeIdentifiers

extension UTType {
    /// Custom type for FDC files
    static var fdc: UTType {
        UTType(importedAs: "it.fdc.railwaynetwork")
    }
    
    /// Industry standard RailML type
    static var railml: UTType {
        UTType(importedAs: "org.railml")
    }

    /// New FDC V2 Qualified Format
    static var rail: UTType {
        UTType(importedAs: "it.fdc.railv2")
    }
}
