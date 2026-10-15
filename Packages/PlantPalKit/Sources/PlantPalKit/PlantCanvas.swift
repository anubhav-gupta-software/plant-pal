import SwiftUI

public struct PlantScene: View {
    public var species: PlantSpecies
    public var pot: PotStyle
    public var stage: GrowthStage
    public var wilt: WiltLevel
    public var isWatering: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        species: PlantSpecies,
        pot: PotStyle,
        stage: GrowthStage,
        wilt: WiltLevel,
        isWatering: Bool = false
    ) {
        self.species = species
        self.pot = pot
        self.stage = stage
        self.wilt = wilt
        self.isWatering = isWatering
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion && !isWatering)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            PlantCanvas(
                species: species,
                pot: pot,
                stage: stage,
                wilt: wilt,
                sway: reduceMotion ? 0 : sin(time * 1.35),
                dropPhase: isWatering ? time.truncatingRemainder(dividingBy: 1.2) / 1.2 : nil
            )
        }
    }
}

public struct PlantBadge: View {
    public var species: PlantSpecies
    public var pot: PotStyle
    public var stage: GrowthStage
    public var wilt: WiltLevel

    public init(species: PlantSpecies, pot: PotStyle, stage: GrowthStage, wilt: WiltLevel = .perky) {
        self.species = species
        self.pot = pot
        self.stage = stage
        self.wilt = wilt
    }

    public var body: some View {
        PlantCanvas(species: species, pot: pot, stage: stage, wilt: wilt, sway: 0, dropPhase: nil)
    }
}

public struct PlantCanvas: View {
    public var species: PlantSpecies
    public var pot: PotStyle
    public var stage: GrowthStage
    public var wilt: WiltLevel
    public var sway: Double
    public var dropPhase: Double?

    public init(
        species: PlantSpecies,
        pot: PotStyle,
        stage: GrowthStage,
        wilt: WiltLevel,
        sway: Double = 0,
        dropPhase: Double? = nil
    ) {
        self.species = species
        self.pot = pot
        self.stage = stage
        self.wilt = wilt
        self.sway = sway
        self.dropPhase = dropPhase
    }

    public var body: some View {
        Color.clear
            .aspectRatio(0.78, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    drawing(in: geo.size)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(species.displayName) in a \(pot.displayName.lowercased()) pot, \(stage.title.lowercased()), \(wilt.title.lowercased())")
    }

    private var look: SpeciesLook { SpeciesLook(species: species, wilt: wilt) }
    private var potLook: PotLook { PotLook(style: pot) }

    private func drawing(in size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let soilY = h * 0.695
        let droop = [0.0, 8.0, 16.0, 26.0][min(wilt.rawValue, 3)]
        let angle = droop + sway * (wilt == .crisis ? 1.4 : 3.4)

        return ZStack {
            Ellipse()
                .fill(PlantTheme.soil.opacity(0.10))
                .frame(width: w * 0.50, height: h * 0.04)
                .position(x: w * 0.5, y: h * 0.925)

            potView(width: w, height: h)
            soilView(width: w, height: h, soilY: soilY)

            if stage == .seed {
                SeedBody(look: look, sad: wilt.rawValue >= 2)
                    .frame(width: w * 0.22, height: h * 0.13)
                    .rotationEffect(.degrees(sway * 5))
                    .position(x: w * 0.5, y: soilY - h * 0.045)
            } else {
                grownPlant(width: w, height: h)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .position(x: w * 0.5, y: soilY - grownHeight(h) / 2)
            }

            if let dropPhase {
                drops(width: w, height: h, phase: dropPhase)
            }
        }
    }

    private func grownHeight(_ h: CGFloat) -> CGFloat {
        h * (stemFraction + flowerFraction)
    }

    private var stemFraction: CGFloat {
        switch stage {
        case .seed: return 0
        case .sprout: return 0.13
        case .seedling: return 0.22
        case .leafy: return 0.32
        case .budding: return 0.34
        case .bloom: return 0.33
        }
    }

    private var flowerFraction: CGFloat {
        switch stage {
        case .seed, .sprout, .seedling: return 0
        case .leafy: return look.species == .moonfern ? 0.02 : 0
        case .budding: return 0.12
        case .bloom: return 0.20
        }
    }

    private var leafCount: Int {
        switch stage {
        case .seed: return 0
        case .sprout: return 2
        case .seedling: return 4
        case .leafy, .budding, .bloom: return look.fern ? 7 : 6
        }
    }

    private func grownPlant(width w: CGFloat, height h: CGFloat) -> some View {
        let stemH = h * stemFraction
        let flowerH = h * flowerFraction
        return VStack(spacing: 0) {
            if flowerH > 1 {
                flower(size: min(w * 0.46, flowerH * 1.35))
                    .frame(height: flowerH)
            }
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(look.stem)
                    .frame(width: max(4, w * (look.mushroom && stage == .bloom ? 0.07 : 0.028)), height: stemH)
                if look.thorns && stage.rawValue >= GrowthStage.leafy.rawValue {
                    thorns(stemH: stemH, width: w)
                }
                leaves(stemH: stemH, width: w)
            }
            .frame(height: stemH)
        }
        .frame(width: w, height: grownHeight(h), alignment: .bottom)
    }

    private func leaves(stemH: CGFloat, width: CGFloat) -> some View {
        ForEach(0..<leafCount, id: \.self) { index in
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let along = CGFloat(index + 1) / CGFloat(leafCount + 1)
            LeafShape(fern: look.fern)
                .fill(index.isMultiple(of: 2) ? look.leaf : look.leafDark)
                .overlay(
                    LeafShape(fern: look.fern)
                        .stroke(look.leafDark.opacity(0.45), lineWidth: 1)
                )
                .frame(
                    width: width * (look.fern ? 0.16 : 0.22),
                    height: width * (look.fern ? 0.28 : 0.13)
                )
                .rotationEffect(.degrees(Double(side) * (look.fern ? -18 : -48)))
                .offset(x: side * width * (look.fern ? 0.08 : 0.11), y: -stemH * along)
        }
    }

    private func thorns(stemH: CGFloat, width: CGFloat) -> some View {
        ForEach(0..<3, id: \.self) { index in
            let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            Thorn()
                .fill(Color(red: 0.45, green: 0.32, blue: 0.22))
                .frame(width: width * 0.045, height: width * 0.035)
                .rotationEffect(.degrees(side > 0 ? 20 : 160))
                .offset(x: side * width * 0.04, y: -stemH * (0.25 + CGFloat(index) * 0.22))
        }
    }

    @ViewBuilder
    private func flower(size: CGFloat) -> some View {
        if look.mushroom {
            MushroomCap(size: size, open: stage == .bloom, look: look, sad: wilt.rawValue >= 2)
        } else if stage == .budding {
            Bud(size: size * 0.72, look: look)
        } else if look.star {
            StarFlower(size: size, look: look, sad: wilt.rawValue >= 2)
        } else if look.rose {
            RoseFlower(size: size, look: look, sad: wilt.rawValue >= 2)
        } else {
            SimpleFlower(petals: look.fern ? 5 : 6, size: size, look: look, sad: wilt.rawValue >= 2)
        }
    }

    private func potView(width w: CGFloat, height h: CGFloat) -> some View {
        let potW = w * 0.64
        let potH = h * 0.25
        return ZStack {
            PotShape()
                .fill(
                    LinearGradient(
                        colors: [potLook.body, potLook.shadow],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            PotShape()
                .stroke(potLook.shadow.opacity(0.9), lineWidth: 2)
            potDecoration(width: potW, height: potH)
            Capsule()
                .fill(potLook.rim)
                .frame(width: potW * 1.08, height: potH * 0.2)
                .overlay(Capsule().stroke(potLook.shadow.opacity(0.35), lineWidth: 1))
                .offset(y: -potH * 0.40)
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: potW * 0.12, height: potH * 0.42)
                .offset(x: -potW * 0.18, y: potH * 0.02)
        }
        .frame(width: potW, height: potH)
        .position(x: w * 0.5, y: h * 0.80)
    }

    @ViewBuilder
    private func potDecoration(width potW: CGFloat, height potH: CGFloat) -> some View {
        switch pot {
        case .ceramic:
            Capsule()
                .fill(Color(red: 0.29, green: 0.48, blue: 0.72))
                .frame(width: potW * 0.72, height: potH * 0.08)
                .offset(y: potH * 0.08)
        case .moss:
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(Color(red: 0.22, green: 0.40, blue: 0.24).opacity(0.45))
                    .frame(width: potW * 0.06, height: potW * 0.06)
                    .offset(x: CGFloat(index - 2) * potW * 0.12, y: potH * 0.06)
            }
        case .galaxy:
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: index.isMultiple(of: 2) ? 3 : 2, height: index.isMultiple(of: 2) ? 3 : 2)
                    .offset(
                        x: CGFloat((index % 3) - 1) * potW * 0.16,
                        y: CGFloat(index / 3) * potH * 0.12 - potH * 0.02
                    )
            }
        case .seashell:
            SeashellArc()
                .stroke(Color.white.opacity(0.7), lineWidth: 2)
                .frame(width: potW * 0.28, height: potH * 0.28)
                .offset(y: potH * 0.04)
        case .golden:
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: potW * 0.7, height: potH * 0.06)
                .offset(y: -potH * 0.02)
        case .terracotta:
            EmptyView()
        }
    }

    private func soilView(width w: CGFloat, height h: CGFloat, soilY: CGFloat) -> some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.45, green: 0.30, blue: 0.18), Color(red: 0.28, green: 0.17, blue: 0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: w * 0.46, height: h * 0.055)
            .position(x: w * 0.5, y: soilY)
    }

    private func drops(width w: CGFloat, height h: CGFloat, phase: Double) -> some View {
        ForEach(0..<4, id: \.self) { index in
            let local = (phase + Double(index) * 0.23).truncatingRemainder(dividingBy: 1)
            DropShape()
                .fill(PlantTheme.water.opacity(0.95 - local * 0.4))
                .frame(width: w * 0.045, height: w * 0.065)
                .position(
                    x: w * (0.32 + CGFloat(index) * 0.12),
                    y: h * (0.08 + CGFloat(local) * 0.55)
                )
                .opacity(local < 0.9 ? 1 : (1 - local) * 10)
        }
    }
}

private struct SpeciesLook {
    var species: PlantSpecies
    var leaf: Color
    var leafDark: Color
    var stem: Color
    var petal: Color
    var petalDeep: Color
    var center: Color
    var fern: Bool
    var rose: Bool
    var mushroom: Bool
    var star: Bool
    var thorns: Bool

    init(species: PlantSpecies, wilt: WiltLevel) {
        self.species = species
        let amount = [0.0, 0.22, 0.45, 0.62][min(wilt.rawValue, 3)]
        let brown = RGB(r: 0.55, g: 0.40, b: 0.25)
        func tone(_ rgb: RGB) -> Color { rgb.mix(toward: brown, amount: amount).color }

        switch species {
        case .sproutling:
            leaf = tone(RGB(r: 0.36, g: 0.70, b: 0.40))
            leafDark = tone(RGB(r: 0.20, g: 0.50, b: 0.30))
            petal = tone(RGB(r: 0.98, g: 0.82, b: 0.36))
            petalDeep = tone(RGB(r: 0.93, g: 0.66, b: 0.22))
            center = tone(RGB(r: 0.96, g: 0.55, b: 0.28))
            fern = false; rose = false; mushroom = false; star = false; thorns = false
        case .sunbloom:
            leaf = tone(RGB(r: 0.45, g: 0.68, b: 0.28))
            leafDark = tone(RGB(r: 0.28, g: 0.48, b: 0.16))
            petal = tone(RGB(r: 0.98, g: 0.72, b: 0.22))
            petalDeep = tone(RGB(r: 0.90, g: 0.48, b: 0.14))
            center = tone(RGB(r: 0.62, g: 0.32, b: 0.12))
            fern = false; rose = false; mushroom = false; star = false; thorns = false
        case .moonfern:
            leaf = tone(RGB(r: 0.62, g: 0.75, b: 0.72))
            leafDark = tone(RGB(r: 0.38, g: 0.55, b: 0.58))
            petal = tone(RGB(r: 0.93, g: 0.94, b: 0.90))
            petalDeep = tone(RGB(r: 0.75, g: 0.80, b: 0.84))
            center = tone(RGB(r: 0.78, g: 0.78, b: 0.55))
            fern = true; rose = false; mushroom = false; star = false; thorns = false
        case .rosythorn:
            leaf = tone(RGB(r: 0.30, g: 0.55, b: 0.32))
            leafDark = tone(RGB(r: 0.18, g: 0.38, b: 0.24))
            petal = tone(RGB(r: 0.91, g: 0.45, b: 0.52))
            petalDeep = tone(RGB(r: 0.72, g: 0.24, b: 0.36))
            center = tone(RGB(r: 0.55, g: 0.16, b: 0.24))
            fern = false; rose = true; mushroom = false; star = false; thorns = true
        case .bubbleshroom:
            leaf = tone(RGB(r: 0.55, g: 0.62, b: 0.32))
            leafDark = tone(RGB(r: 0.36, g: 0.42, b: 0.20))
            petal = tone(RGB(r: 0.86, g: 0.36, b: 0.32))
            petalDeep = tone(RGB(r: 0.95, g: 0.86, b: 0.74))
            center = tone(RGB(r: 0.95, g: 0.92, b: 0.84))
            fern = false; rose = false; mushroom = true; star = false; thorns = false
        case .starlily:
            leaf = tone(RGB(r: 0.32, g: 0.52, b: 0.46))
            leafDark = tone(RGB(r: 0.18, g: 0.34, b: 0.36))
            petal = tone(RGB(r: 0.62, g: 0.48, b: 0.86))
            petalDeep = tone(RGB(r: 0.38, g: 0.28, b: 0.66))
            center = tone(RGB(r: 0.96, g: 0.90, b: 0.55))
            fern = false; rose = false; mushroom = false; star = true; thorns = false
        }
        stem = leafDark
    }
}

private struct PotLook {
    var body: Color
    var shadow: Color
    var rim: Color

    init(style: PotStyle) {
        switch style {
        case .terracotta:
            body = Color(red: 0.84, green: 0.48, blue: 0.32)
            shadow = Color(red: 0.62, green: 0.30, blue: 0.18)
            rim = Color(red: 0.90, green: 0.56, blue: 0.38)
        case .ceramic:
            body = Color(red: 0.96, green: 0.96, blue: 0.94)
            shadow = Color(red: 0.72, green: 0.76, blue: 0.80)
            rim = Color(red: 0.29, green: 0.48, blue: 0.72)
        case .moss:
            body = Color(red: 0.42, green: 0.55, blue: 0.36)
            shadow = Color(red: 0.24, green: 0.36, blue: 0.22)
            rim = Color(red: 0.33, green: 0.46, blue: 0.28)
        case .galaxy:
            body = Color(red: 0.22, green: 0.18, blue: 0.40)
            shadow = Color(red: 0.10, green: 0.08, blue: 0.20)
            rim = Color(red: 0.42, green: 0.36, blue: 0.68)
        case .seashell:
            body = Color(red: 0.96, green: 0.78, blue: 0.68)
            shadow = Color(red: 0.84, green: 0.58, blue: 0.50)
            rim = Color(red: 0.99, green: 0.88, blue: 0.80)
        case .golden:
            body = Color(red: 0.92, green: 0.74, blue: 0.32)
            shadow = Color(red: 0.70, green: 0.50, blue: 0.14)
            rim = Color(red: 0.98, green: 0.86, blue: 0.48)
        }
    }
}

private struct RGB {
    var r, g, b: Double
    var color: Color { Color(red: r, green: g, blue: b) }
    func mix(toward other: RGB, amount: Double) -> RGB {
        RGB(
            r: r + (other.r - r) * amount,
            g: g + (other.g - g) * amount,
            b: b + (other.b - b) * amount
        )
    }
}

private struct LeafShape: Shape {
    var fern: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if fern {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.minY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )
        } else {
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.minY),
                control: CGPoint(x: rect.maxX, y: rect.midY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY),
                control: CGPoint(x: rect.minX, y: rect.midY)
            )
        }
        return path
    }
}

private struct PotShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topY = rect.minY + rect.height * 0.16
        let bottomY = rect.maxY - 4
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.06, y: topY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.06, y: topY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.18, y: bottomY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.18, y: bottomY),
            control: CGPoint(x: rect.midX, y: rect.maxY + 8)
        )
        path.closeSubpath()
        return path
    }
}

private struct DropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.midY)
        )
        return path
    }
}

private struct Thorn: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct SeashellArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width * 0.45,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        return path
    }
}

private struct SeedBody: View {
    var look: SpeciesLook
    var sad: Bool
    var body: some View {
        ZStack {
            Ellipse()
                .fill(look.leafDark)
                .offset(y: 3)
            Ellipse()
                .fill(
                    LinearGradient(colors: [look.leaf, look.leafDark], startPoint: .top, endPoint: .bottom)
                )
            PlantFace(sad: sad)
                .padding(8)
        }
    }
}

private struct SimpleFlower: View {
    var petals: Int
    var size: CGFloat
    var look: SpeciesLook
    var sad: Bool
    var body: some View {
        ZStack {
            ForEach(0..<petals, id: \.self) { index in
                Ellipse()
                    .fill(index.isMultiple(of: 2) ? look.petal : look.petalDeep)
                    .frame(width: size * 0.28, height: size * 0.42)
                    .offset(y: -size * 0.22)
                    .rotationEffect(.degrees(Double(index) / Double(petals) * 360))
            }
            Circle()
                .fill(look.center)
                .frame(width: size * 0.34, height: size * 0.34)
            PlantFace(sad: sad)
                .frame(width: size * 0.28, height: size * 0.28)
        }
        .frame(width: size, height: size)
    }
}

private struct StarFlower: View {
    var size: CGFloat
    var look: SpeciesLook
    var sad: Bool
    var body: some View {
        ZStack {
            StarPolygon(points: 6)
                .fill(look.petalDeep)
                .frame(width: size * 0.92, height: size * 0.92)
            StarPolygon(points: 6)
                .fill(look.petal)
                .frame(width: size * 0.72, height: size * 0.72)
                .rotationEffect(.degrees(18))
            Circle()
                .fill(look.center)
                .frame(width: size * 0.28, height: size * 0.28)
            PlantFace(sad: sad)
                .frame(width: size * 0.24, height: size * 0.24)
        }
        .frame(width: size, height: size)
    }
}

private struct RoseFlower: View {
    var size: CGFloat
    var look: SpeciesLook
    var sad: Bool
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Ellipse()
                    .fill(index.isMultiple(of: 2) ? look.petalDeep : look.petal)
                    .frame(width: size * 0.34, height: size * 0.48)
                    .offset(y: -size * 0.16)
                    .rotationEffect(.degrees(Double(index) * 72))
            }
            Circle()
                .fill(look.petal)
                .frame(width: size * 0.42, height: size * 0.42)
            Circle()
                .fill(look.petalDeep.opacity(0.85))
                .frame(width: size * 0.26, height: size * 0.26)
            PlantFace(sad: sad)
                .frame(width: size * 0.22, height: size * 0.22)
        }
        .frame(width: size, height: size)
    }
}

private struct Bud: View {
    var size: CGFloat
    var look: SpeciesLook
    var body: some View {
        ZStack {
            Ellipse()
                .fill(look.leafDark)
                .frame(width: size * 0.55, height: size * 0.28)
                .offset(y: size * 0.16)
            Ellipse()
                .fill(LinearGradient(colors: [look.petal, look.petalDeep], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.48, height: size * 0.72)
        }
        .frame(width: size, height: size)
    }
}

private struct MushroomCap: View {
    var size: CGFloat
    var open: Bool
    var look: SpeciesLook
    var sad: Bool
    var body: some View {
        ZStack {
            Capsule()
                .fill(look.center)
                .frame(width: size * 0.22, height: size * (open ? 0.42 : 0.28))
                .offset(y: size * 0.16)
            Capsule()
                .fill(look.petal)
                .frame(width: size * (open ? 0.78 : 0.55), height: size * 0.48)
                .offset(y: -size * 0.08)
            HStack(spacing: size * 0.08) {
                Circle().fill(look.petalDeep).frame(width: size * 0.12, height: size * 0.10)
                Circle().fill(Color.white.opacity(0.8)).frame(width: size * 0.08, height: size * 0.07)
                Circle().fill(look.petalDeep).frame(width: size * 0.1, height: size * 0.08)
            }
            .offset(y: -size * 0.12)
            PlantFace(sad: sad)
                .frame(width: size * 0.28, height: size * 0.22)
                .offset(y: size * 0.22)
        }
        .frame(width: size, height: size)
    }
}

private struct StarPolygon: Shape {
    var points: Int
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<(points * 2) {
            let angle = (Double(index) * .pi / Double(points)) - .pi / 2
            let length = index.isMultiple(of: 2) ? radius : radius * 0.48
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * length,
                y: center.y + CGFloat(sin(angle)) * length
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private struct PlantFace: View {
    var sad: Bool
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let eye = max(2, w * 0.12)
            ZStack {
                HStack(spacing: w * 0.22) {
                    Circle().fill(PlantTheme.soil).frame(width: eye, height: sad ? eye * 0.45 : eye * 1.15)
                    Circle().fill(PlantTheme.soil).frame(width: eye, height: sad ? eye * 0.45 : eye * 1.15)
                }
                .offset(y: -h * 0.08)
                Smile(sad: sad)
                    .stroke(PlantTheme.soil, style: StrokeStyle(lineWidth: max(1.4, w * 0.07), lineCap: .round))
                    .frame(width: w * 0.42, height: h * 0.22)
                    .offset(y: h * 0.18)
                HStack(spacing: w * 0.46) {
                    Circle().fill(PlantTheme.blush.opacity(0.95)).frame(width: w * 0.16, height: h * 0.12)
                    Circle().fill(PlantTheme.blush.opacity(0.95)).frame(width: w * 0.16, height: h * 0.12)
                }
                .offset(y: h * 0.12)
            }
            .frame(width: w, height: h)
        }
    }
}

private struct Smile: Shape {
    var sad: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: sad ? rect.maxY : rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: sad ? rect.maxY : rect.minY),
            control: CGPoint(x: rect.midX, y: sad ? rect.minY : rect.maxY)
        )
        return path
    }
}
