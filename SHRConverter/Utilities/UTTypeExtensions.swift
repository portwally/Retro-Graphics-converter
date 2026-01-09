import UniformTypeIdentifiers

// MARK: - Custom UTType Extensions for Retro Image Formats

extension UTType {
    static var pcx: UTType {
        UTType(filenameExtension: "pcx") ?? .data
    }
    
    static var shr: UTType {
        UTType(filenameExtension: "shr") ?? .data
    }
    
    static var pic: UTType {
        UTType(filenameExtension: "pic") ?? .data
    }
    
    static var pnt: UTType {
        UTType(filenameExtension: "pnt") ?? .data
    }
    
    static var twoimg: UTType {
        UTType(filenameExtension: "2img") ?? .data
    }
    
    static var dsk: UTType {
        UTType(filenameExtension: "dsk") ?? .data
    }
    
    static var hdv: UTType {
        UTType(filenameExtension: "hdv") ?? .data
    }
}
