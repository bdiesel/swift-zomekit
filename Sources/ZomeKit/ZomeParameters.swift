import Foundation

/// Parametric inputs to a zome. Unit-agnostic — the caller decides whether
/// these are inches, millimetres, or anything else; ZomeKit just does math.
public struct ZomeParameters: Equatable, Sendable, Codable {
    /// Number of spirals / rotational symmetry order. Each spiral covers `360°/N` around the Y axis.
    public var numSpirals: Int
    /// Tilt of the first crown edge from the apex axis, in degrees. Drives the dome's steepness.
    public var thetaDegrees: Double
    /// Multiplicative ratio between successive crown edge lengths. `1.0` is a rhombus zome.
    public var kiteRatio: Double
    /// Fraction of the total construction height occupied by the timbered roof (`zomeHeight / totalHeight`).
    public var heightRatio: Double
    /// Vertical extent of the timbered shell above the ground plane.
    public var zomeHeight: Double
    /// Width of each timber (inward dimension, perpendicular to the face).
    public var timberWidth: Double
    /// Thickness of each timber (the dimension along the face surface).
    public var timberThickness: Double
    /// Optional radial scaling per crown index. Empty = no bindu adjustment.
    public var binduRatios: [Double]
    /// Y coordinate of the GoodKarma vanishing point. `nil` = auto-compute as the centroid of the dome.
    public var vanishingY: Double?
    /// How timber prisms are framed against the faces. Defaults to GoodKarma.
    public var assemblyMethod: AssemblyMethod

    public init(
        numSpirals: Int,
        thetaDegrees: Double,
        kiteRatio: Double,
        heightRatio: Double,
        zomeHeight: Double,
        timberWidth: Double,
        timberThickness: Double,
        binduRatios: [Double] = [],
        vanishingY: Double? = nil,
        assemblyMethod: AssemblyMethod = .goodKarma
    ) {
        self.numSpirals = numSpirals
        self.thetaDegrees = thetaDegrees
        self.kiteRatio = kiteRatio
        self.heightRatio = heightRatio
        self.zomeHeight = zomeHeight
        self.timberWidth = timberWidth
        self.timberThickness = timberThickness
        self.binduRatios = binduRatios
        self.vanishingY = vanishingY
        self.assemblyMethod = assemblyMethod
    }

    /// Brian's reference screenshot: 122" × 151.0625" envelope, 270 timbers in 16 sizes.
    public static let goodKarmaDefault = ZomeParameters(
        numSpirals: 10,
        thetaDegrees: 53.25,
        kiteRatio: 1.0,
        heightRatio: 0.7,
        zomeHeight: 122.0,
        timberWidth: 3.5,
        timberThickness: 1.5
    )

    // MARK: - Codable (custom decoder so 0.1.x .zome files without
    // `assemblyMethod` load cleanly with the GoodKarma default)

    private enum CodingKeys: String, CodingKey {
        case numSpirals, thetaDegrees, kiteRatio, heightRatio, zomeHeight,
             timberWidth, timberThickness, binduRatios, vanishingY, assemblyMethod
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.numSpirals      = try c.decode(Int.self,      forKey: .numSpirals)
        self.thetaDegrees    = try c.decode(Double.self,   forKey: .thetaDegrees)
        self.kiteRatio       = try c.decode(Double.self,   forKey: .kiteRatio)
        self.heightRatio     = try c.decode(Double.self,   forKey: .heightRatio)
        self.zomeHeight      = try c.decode(Double.self,   forKey: .zomeHeight)
        self.timberWidth     = try c.decode(Double.self,   forKey: .timberWidth)
        self.timberThickness = try c.decode(Double.self,   forKey: .timberThickness)
        self.binduRatios     = try c.decodeIfPresent([Double].self, forKey: .binduRatios) ?? []
        self.vanishingY      = try c.decodeIfPresent(Double.self,   forKey: .vanishingY)
        self.assemblyMethod  = try c.decodeIfPresent(AssemblyMethod.self, forKey: .assemblyMethod) ?? .goodKarma
    }
}

extension ZomeParameters {
    var totalHeight: Double { zomeHeight / heightRatio }
    var thetaRadians: Double { thetaDegrees * .pi / 180.0 }

    /// `Σ kᵢ` for i in 0..<N. Becomes `N` when k = 1 (rhombus zome).
    var kSum: Double {
        kiteRatio == 1.0
            ? Double(numSpirals)
            : (1.0 - pow(kiteRatio, Double(numSpirals))) / (1.0 - kiteRatio)
    }

    var firstEdge: Double { totalHeight / (kSum * cos(thetaRadians)) }
    var firstCrownRadius: Double { firstEdge * sin(thetaRadians) }
    var firstCrownHeight: Double { firstEdge * cos(thetaRadians) }
}
