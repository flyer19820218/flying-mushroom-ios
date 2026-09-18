import SwiftUI
import MapKit
import UniformTypeIdentifiers
import UIKit

enum MobileTool: String, Identifiable, CaseIterable {
    case singlePoint
    case multiPoint
    case route
    case gpx
    case crossDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singlePoint: return "單點 GPS"
        case .multiPoint: return "多點座標"
        case .route: return "路線"
        case .gpx: return "GPX 匯入"
        case .crossDay: return "跨日工具"
        }
    }

    var shortTitle: String {
        switch self {
        case .singlePoint: return "單點"
        case .multiPoint: return "多點"
        case .route: return "路線"
        case .gpx: return "GPX"
        case .crossDay: return "跨日"
        }
    }

    var symbol: String {
        switch self {
        case .singlePoint: return "mappin.and.ellipse"
        case .multiPoint: return "point.3.connected.trianglepath.dotted"
        case .route: return "figure.walk"
        case .gpx: return "doc.badge.arrow.up"
        case .crossDay: return "globe.asia.australia.fill"
        }
    }
}

struct MobileRoutePlan {
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let speedKPH: Double
}

struct MobileToolDock: View {
    let selectedTool: MobileTool?
    let onSelect: (MobileTool?) -> Void

    var body: some View {
        HStack(spacing: 2) {
            dockButton(title: "地圖", symbol: "map.fill", selected: selectedTool == nil) {
                onSelect(nil)
            }

            ForEach(MobileTool.allCases) { tool in
                dockButton(title: tool.shortTitle, symbol: tool.symbol, selected: selectedTool == tool) {
                    onSelect(tool)
                }
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
    }

    private func dockButton(
        title: String,
        symbol: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(selected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ToolSheetHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SinglePointToolView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coordinateText: String
    @State private var bookmarkName = ""
    @State private var savedLocations: [LocationBookmark] = []
    @State private var saveMessage: String?
    @FocusState private var isFocused: Bool

    let onSimulate: (CLLocationCoordinate2D) -> Void
    let onClear: () -> Void

    init(
        initialCoordinate: CLLocationCoordinate2D? = nil,
        onSimulate: @escaping (CLLocationCoordinate2D) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.onSimulate = onSimulate
        self.onClear = onClear
        _coordinateText = State(initialValue: initialCoordinate.map {
            String(format: "%.7f, %.7f", $0.latitude, $0.longitude)
        } ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                ToolSheetHeader(
                    title: "貼上座標",
                    subtitle: "括號、逗號或空白都可以，會自動判斷順序。"
                )

                HStack(spacing: 10) {
                    TextField("例如：(25.033964, 121.564468)", text: $coordinateText)
                        .textFieldStyle(.plain)
                        .font(.body.monospaced())
                        .keyboardType(.numbersAndPunctuation)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit(startSimulation)
                        .onChange(of: coordinateText) { _, _ in saveMessage = nil }

                    Button {
                        if let string = UIPasteboard.general.string {
                            coordinateText = string.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.title3.weight(.semibold))
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("從剪貼簿貼上")
                }
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))

                Group {
                    if let coordinate {
                        Label(
                            String(format: "已辨識  %.6f, %.6f", coordinate.latitude, coordinate.longitude),
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                    } else if !coordinateText.isEmpty {
                        Label("找不到一組有效座標", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    } else {
                        Text("支援：25.03,121.56　(25.03 121.56)　121.56,25.03")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)

                Button(action: startSimulation) {
                    Label("設定位置", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(coordinate == nil)

                VStack(alignment: .leading, spacing: 10) {
                    Label("儲存單點位置", systemImage: "bookmark")
                        .font(.headline)

                    if let savedAtCoordinate {
                        Label("這個位置已儲存為「\(savedAtCoordinate.name)」", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        TextField("名稱，例如：常用地點", text: $bookmarkName)
                            .textFieldStyle(.roundedBorder)

                        Button(action: saveCurrentLocation) {
                            Label("儲存此位置", systemImage: "bookmark.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(coordinate == nil || trimmedBookmarkName.isEmpty)
                    }

                    if let saveMessage {
                        Text(saveMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("已儲存的位置")
                        .font(.headline)

                    if savedLocations.isEmpty {
                        Text("還沒有收藏；貼上座標並取名後，就能在這裡一鍵定位。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savedLocations) { bookmark in
                            Button {
                                dismiss()
                                onSimulate(bookmark.coordinate)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(.tint)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bookmark.name)
                                            .foregroundStyle(.primary)
                                        Text(String(format: "%.6f, %.6f", bookmark.latitude, bookmark.longitude))
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(.tint)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("定位到\(bookmark.name)")
                        }
                        Text("點一下收藏位置，即可立即定位。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(role: .destructive) {
                    dismiss()
                    onClear()
                } label: {
                    Label("停止並恢復真實定位", systemImage: "location.slash.fill")
                        .frame(maxWidth: .infinity)
                }
                }
                .padding(20)
            }
            .navigationTitle("單點")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                savedLocations = BookmarkStore.load()
                isFocused = coordinateText.isEmpty && savedLocations.isEmpty
            }
        }
    }

    private var coordinate: CLLocationCoordinate2D? {
        MobileCoordinateParser.parseSingle(coordinateText)
    }

    private var trimmedBookmarkName: String {
        bookmarkName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var savedAtCoordinate: LocationBookmark? {
        guard let coordinate else { return nil }
        return BookmarkStore.bookmark(nearest: coordinate, in: savedLocations)
    }

    private func saveCurrentLocation() {
        guard let coordinate, !trimmedBookmarkName.isEmpty else { return }

        var latest = BookmarkStore.load()
        if let existing = BookmarkStore.bookmark(nearest: coordinate, in: latest) {
            savedLocations = latest
            saveMessage = "這個位置已儲存為「\(existing.name)」"
            return
        }

        latest.append(LocationBookmark(
            name: trimmedBookmarkName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ))
        BookmarkStore.save(latest)
        savedLocations = latest
        saveMessage = "已儲存「\(trimmedBookmarkName)」"
        bookmarkName = ""
        isFocused = false
        Haptics.light()
    }

    private func startSimulation() {
        guard let coordinate else { return }
        dismiss()
        onSimulate(coordinate)
    }
}

enum MobileCoordinateParser {
    private static let numberPattern = #"[-+]?(?:\d+(?:\.\d*)?|\.\d+)"#

    static func parseSingle(_ text: String) -> CLLocationCoordinate2D? {
        guard let regex = try? NSRegularExpression(pattern: numberPattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let values = regex.matches(in: text, range: range).compactMap { match -> Double? in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return Double(text[matchRange])
        }
        guard values.count >= 2 else { return nil }
        return coordinate(first: values[0], second: values[1])
    }

    static func parse(_ text: String) -> [CLLocationCoordinate2D] {
        text.components(separatedBy: .newlines).compactMap(parseSingle)
    }

    private static func coordinate(first: Double, second: Double) -> CLLocationCoordinate2D? {
        let latitude: Double
        let longitude: Double

        // When only one value can be latitude, accept the common lon/lat form
        // automatically. If both fit latitude, Google Maps' usual lat/lon order wins.
        if abs(first) > 90, abs(first) <= 180, abs(second) <= 90 {
            latitude = second
            longitude = first
        } else {
            latitude = first
            longitude = second
        }

        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct MultiPointToolView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coordinateText = ""
    @State private var routeName = ""
    @State private var speedKPH = 19.0
    @State private var errorMessage: String?
    @State private var saveMessage: String?
    @State private var mapPosition: MapCameraPosition

    let initialCoordinate: CLLocationCoordinate2D?
    let onStart: (MobileRoutePlan) -> Void

    init(
        initialCoordinate: CLLocationCoordinate2D? = nil,
        onStart: @escaping (MobileRoutePlan) -> Void
    ) {
        self.initialCoordinate = initialCoordinate
        self.onStart = onStart

        if let initialCoordinate {
            _mapPosition = State(
                initialValue: .region(
                    MKCoordinateRegion(
                        center: initialCoordinate,
                        latitudinalMeters: 1_200,
                        longitudinalMeters: 1_200
                    )
                )
            )
        } else {
            _mapPosition = State(initialValue: .userLocation(fallback: .automatic))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ToolSheetHeader(
                        title: "多點座標",
                        subtitle: "直接點地圖畫路線，或貼上整批座標。"
                    )
                }

                Section("地圖上選點") {
                    MapReader { proxy in
                        Map(position: $mapPosition) {
                            UserAnnotation()

                            if let initialCoordinate, !routeContains(initialCoordinate) {
                                Marker("首頁目的地", systemImage: "scope", coordinate: initialCoordinate)
                                    .tint(.orange)
                            }

                            if parsedPoints.count >= 2 {
                                MapPolyline(coordinates: parsedPoints)
                                    .stroke(
                                        .blue,
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                                    )
                            }

                            ForEach(Array(parsedPoints.enumerated()), id: \.offset) { index, point in
                                Annotation("\(index + 1)", coordinate: point) {
                                    Text("\(index + 1)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 26, height: 26)
                                        .background(index == 0 ? Color.green : Color.blue, in: Circle())
                                        .overlay(Circle().stroke(.white, lineWidth: 2))
                                        .shadow(radius: 2)
                                }
                            }
                        }
                        .mapStyle(.standard(elevation: .realistic))
                        .onTapGesture { screenPoint in
                            guard let point = proxy.convert(screenPoint, from: .local) else { return }
                            appendMapPoint(point)
                        }
                    }
                    .frame(height: 290)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let initialCoordinate {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("已同步首頁目的地", systemImage: "scope")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)

                            Text(formatted(initialCoordinate))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Button {
                                    centerMapOnInitialCoordinate()
                                } label: {
                                    Label("回到目的地", systemImage: "location.magnifyingglass")
                                }

                                if parsedPoints.isEmpty {
                                    Button {
                                        appendMapPoint(initialCoordinate)
                                    } label: {
                                        Label("作為第 1 點", systemImage: "1.circle.fill")
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    } else {
                        Label("尚未選擇目的地；可直接移動地圖選點，或回首頁先選一個位置。", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("點一下地圖加入節點，系統會依數字順序移動。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button {
                            undoLastPoint()
                        } label: {
                            Label("復原上一點", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(parsedPoints.isEmpty)

                        Spacer()

                        Button(role: .destructive) {
                            coordinateText = ""
                        } label: {
                            Label("全部清空", systemImage: "trash")
                        }
                        .disabled(parsedPoints.isEmpty)
                    }
                }

                Section("座標清單") {
                    Text("直接貼上座標；一行一個點。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $coordinateText)
                        .font(.body.monospaced())
                        .frame(minHeight: 170)
                    Text("已辨識 \(parsedPoints.count) 個座標")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                speedSection

                Section("儲存路線") {
                    TextField("路線名稱", text: $routeName)

                    Button {
                        saveCurrentRoute()
                    } label: {
                        Label("儲存到我的路線", systemImage: "bookmark.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(parsedPoints.count < 2 || trimmedRouteName.isEmpty)

                    if let saveMessage {
                        Label(saveMessage, systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.green)
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }

                Button {
                    guard parsedPoints.count >= 2 else {
                        errorMessage = "至少需要兩個有效座標。"
                        return
                    }
                    dismiss()
                    onStart(.init(
                        name: trimmedRouteName.isEmpty ? "多點路線" : trimmedRouteName,
                        coordinates: parsedPoints,
                        speedKPH: speedKPH
                    ))
                } label: {
                    Label("開始移動", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("多點")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
        }
    }

    private var speedSection: some View {
        Section("速度") {
            HStack {
                Slider(value: $speedKPH, in: 1...30, step: 0.5)
                Text("\(speedKPH, specifier: "%.1f") km/h")
                    .monospacedDigit()
                    .frame(width: 92, alignment: .trailing)
            }
        }
    }

    private var parsedPoints: [CLLocationCoordinate2D] {
        MobileCoordinateParser.parse(coordinateText)
    }

    private var trimmedRouteName: String {
        routeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendMapPoint(_ point: CLLocationCoordinate2D) {
        let line = String(format: "%.7f, %.7f", point.latitude, point.longitude)
        if coordinateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            coordinateText = line
        } else {
            coordinateText += "\n\(line)"
        }
        saveMessage = nil
        Haptics.light()
    }

    private func centerMapOnInitialCoordinate() {
        guard let initialCoordinate else { return }
        mapPosition = .region(
            MKCoordinateRegion(
                center: initialCoordinate,
                latitudinalMeters: 1_200,
                longitudinalMeters: 1_200
            )
        )
    }

    private func routeContains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        parsedPoints.contains {
            abs($0.latitude - coordinate.latitude) < 0.000_000_1 &&
            abs($0.longitude - coordinate.longitude) < 0.000_000_1
        }
    }

    private func formatted(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }

    private func undoLastPoint() {
        var points = parsedPoints
        guard !points.isEmpty else { return }
        points.removeLast()
        coordinateText = points
            .map { String(format: "%.7f, %.7f", $0.latitude, $0.longitude) }
            .joined(separator: "\n")
        saveMessage = nil
    }

    private func saveCurrentRoute() {
        do {
            let saved = try SavedRouteStore.save(
                name: trimmedRouteName,
                coordinates: parsedPoints,
                speedKPH: speedKPH
            )
            saveMessage = "已儲存「\(saved.name)」"
            errorMessage = nil
        } catch {
            saveMessage = nil
            errorMessage = "儲存失敗：\(error.localizedDescription)"
        }
    }
}

struct WalkingRouteToolView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var startText = "台北 101"
    @State private var destinationText = "國父紀念館"
    @State private var speedKPH = 19.0
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var savedRoutes: [SavedMobileRoute] = []

    let onStart: (MobileRoutePlan) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ToolSheetHeader(
                        title: "步行路線",
                        subtitle: "輸入起點與終點，自動沿道路規劃。"
                    )
                }

                Section("已儲存的路線") {
                    if savedRoutes.isEmpty {
                        Text("還沒有儲存的路線")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savedRoutes) { route in
                            Button {
                                start(route)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: route.isBuiltIn ? "star.fill" : "bookmark.fill")
                                        .foregroundStyle(route.isBuiltIn ? .yellow : .blue)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(route.name)
                                            .foregroundStyle(.primary)
                                        Text("\(route.points.count) 點 · \(route.speedKPH, specifier: "%.1f") km/h")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if !route.isBuiltIn {
                                    Button(role: .destructive) {
                                        delete(route)
                                    } label: {
                                        Label("刪除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                Section("地點") {
                    Label {
                        TextField("起點", text: $startText)
                    } icon: { Image(systemName: "circle.fill").foregroundStyle(.green) }

                    Label {
                        TextField("終點", text: $destinationText)
                    } icon: { Image(systemName: "mappin.circle.fill").foregroundStyle(.red) }
                }

                Section("速度") {
                    HStack {
                        Slider(value: $speedKPH, in: 1...30, step: 0.5)
                        Text("\(speedKPH, specifier: "%.1f") km/h")
                            .monospacedDigit()
                            .frame(width: 92, alignment: .trailing)
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }

                Button {
                    Task { await buildRoute() }
                } label: {
                    HStack {
                        if isWorking { ProgressView().tint(.white) }
                        Label(isWorking ? "正在規劃…" : "規劃並開始", systemImage: "figure.walk")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking || startText.isEmpty || destinationText.isEmpty)
            }
            .navigationTitle("路線")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
            .onAppear(perform: reloadSavedRoutes)
        }
    }

    private func reloadSavedRoutes() {
        savedRoutes = SavedRouteStore.load()
    }

    private func start(_ route: SavedMobileRoute) {
        dismiss()
        onStart(route.plan)
    }

    private func delete(_ route: SavedMobileRoute) {
        do {
            try SavedRouteStore.delete(id: route.id)
            reloadSavedRoutes()
            errorMessage = nil
        } catch {
            errorMessage = "刪除失敗：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func buildRoute() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            async let start = resolve(startText)
            async let destination = resolve(destinationText)
            let (startCoordinate, destinationCoordinate) = try await (start, destination)

            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: startCoordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
            request.transportType = .walking
            request.requestsAlternateRoutes = false

            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                throw RouteToolError.noRoute
            }

            let polyline = route.polyline
            let points = polyline.points()
            let coordinates = (0..<polyline.pointCount).map { points[$0].coordinate }
            guard coordinates.count >= 2 else { throw RouteToolError.noRoute }

            dismiss()
            onStart(.init(
                name: "\(startText) → \(destinationText)",
                coordinates: coordinates,
                speedKPH: speedKPH
            ))
        } catch {
            errorMessage = "找不到可用步行路線：\(error.localizedDescription)"
        }
    }

    private func resolve(_ query: String) async throws -> CLLocationCoordinate2D {
        if let direct = MobileCoordinateParser.parse(query).first { return direct }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try await MKLocalSearch(request: request).start()
        guard let coordinate = response.mapItems.first?.placemark.coordinate else {
            throw RouteToolError.placeNotFound
        }
        return coordinate
    }

    private enum RouteToolError: LocalizedError {
        case placeNotFound
        case noRoute

        var errorDescription: String? {
            switch self {
            case .placeNotFound: return "找不到地點"
            case .noRoute: return "沒有步行路線"
            }
        }
    }
}

struct GPXImportToolView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var speedKPH = 19.0
    @State private var isImporting = false
    @State private var importedName = ""
    @State private var importedCoordinates: [CLLocationCoordinate2D] = []
    @State private var errorMessage: String?

    let onStart: (MobileRoutePlan) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ToolSheetHeader(
                        title: "GPX 匯入",
                        subtitle: "讀取 trkpt、rtept 或 wpt，直接在手機播放。"
                    )
                }

                Section {
                    Button {
                        isImporting = true
                    } label: {
                        Label("選擇 GPX 檔案", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }

                    if !importedCoordinates.isEmpty {
                        Label("\(importedName) · \(importedCoordinates.count) 點", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Section("速度") {
                    HStack {
                        Slider(value: $speedKPH, in: 1...30, step: 0.5)
                        Text("\(speedKPH, specifier: "%.1f") km/h")
                            .monospacedDigit()
                            .frame(width: 92, alignment: .trailing)
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }

                Button {
                    guard importedCoordinates.count >= 2 else { return }
                    dismiss()
                    onStart(.init(
                        name: importedName.isEmpty ? "GPX 路線" : importedName,
                        coordinates: importedCoordinates,
                        speedKPH: speedKPH
                    ))
                } label: {
                    Label("開始播放 GPX", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(importedCoordinates.count < 2)
            }
            .navigationTitle("GPX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
            .fileImporter(
                isPresented: $isImporting,
                // GPX has no system-declared UTI on many iOS versions. Asking
                // for a dynamic "GPX conforms to XML" type makes Files reject
                // otherwise valid .gpx files. Let the user select a file and
                // validate its extension and XML content ourselves instead.
                allowedContentTypes: [.item]
            ) { result in
                importGPX(result)
            }
        }
    }

    private func importGPX(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard ["gpx", "xml"].contains(url.pathExtension.lowercased()) else {
                throw GPXError.unsupportedFile
            }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let parser = GPXCoordinateParser(data: data)
            let coordinates = try parser.parse()
            guard coordinates.count >= 2 else { throw GPXError.notEnoughPoints }
            importedName = url.deletingPathExtension().lastPathComponent
            importedCoordinates = coordinates
            errorMessage = nil
        } catch {
            importedCoordinates = []
            errorMessage = "無法讀取 GPX：\(error.localizedDescription)"
        }
    }

    private enum GPXError: LocalizedError {
        case notEnoughPoints
        case unsupportedFile

        var errorDescription: String? {
            switch self {
            case .notEnoughPoints: return "GPX 至少需要兩個座標點"
            case .unsupportedFile: return "請選擇 .gpx 檔案"
            }
        }
    }
}

final class GPXCoordinateParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var coordinates: [CLLocationCoordinate2D] = []

    init(data: Data) {
        self.data = data
    }

    func parse() throws -> [CLLocationCoordinate2D] {
        coordinates.removeAll(keepingCapacity: true)
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true
        guard parser.parse() else {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        return coordinates
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let pointElement = elementName.split(separator: ":").last.map(String.init)?.lowercased()
        guard let pointElement, ["trkpt", "rtept", "wpt"].contains(pointElement),
              let latText = attributeDict["lat"], let lonText = attributeDict["lon"],
              let lat = Double(latText), let lon = Double(lonText),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return }
        coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
}

private struct CrossDayPlace: Identifiable {
    let city: String
    let timeZoneID: String
    let latitude: Double
    let longitude: Double

    var id: String { timeZoneID }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func hour(at date: Date) -> Int? {
        guard let zone = TimeZone(identifier: timeZoneID) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.component(.hour, from: date)
    }

    func timeText(at date: Date) -> String {
        formatted(date, pattern: "HH:mm")
    }

    func dateText(at date: Date) -> String {
        formatted(date, pattern: "yyyy-MM-dd")
    }

    func utcText(at date: Date) -> String {
        guard let zone = TimeZone(identifier: timeZoneID) else { return "UTC" }
        let seconds = zone.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "−"
        let absolute = abs(seconds)
        let hours = absolute / 3600
        let minutes = (absolute % 3600) / 60
        return minutes == 0 ? "UTC\(sign)\(hours)" : String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }

    private func formatted(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.timeZone = TimeZone(identifier: timeZoneID)
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

private enum CrossDayPlaces {
    static let all: [CrossDayPlace] = [
        .init(city: "帕果帕果", timeZoneID: "Pacific/Pago_Pago", latitude: -14.2756, longitude: -170.7040),
        .init(city: "檀香山", timeZoneID: "Pacific/Honolulu", latitude: 21.3069, longitude: -157.8583),
        .init(city: "甘比爾", timeZoneID: "Pacific/Gambier", latitude: -23.13, longitude: -134.97),
        .init(city: "皮特肯", timeZoneID: "Pacific/Pitcairn", latitude: -25.066, longitude: -130.1),
        .init(city: "鳳凰城", timeZoneID: "America/Phoenix", latitude: 33.4484, longitude: -112.074),
        .init(city: "瓜地馬拉市", timeZoneID: "America/Guatemala", latitude: 14.6349, longitude: -90.5069),
        .init(city: "波哥大", timeZoneID: "America/Bogota", latitude: 4.711, longitude: -74.072),
        .init(city: "聖多明哥", timeZoneID: "America/Santo_Domingo", latitude: 18.4861, longitude: -69.9312),
        .init(city: "布宜諾斯艾利斯", timeZoneID: "America/Argentina/Buenos_Aires", latitude: -34.6037, longitude: -58.3816),
        .init(city: "費爾南多迪諾羅尼亞", timeZoneID: "America/Noronha", latitude: -3.8547, longitude: -32.4233),
        .init(city: "培亞", timeZoneID: "Atlantic/Cape_Verde", latitude: 14.933, longitude: -23.513),
        .init(city: "阿比讓", timeZoneID: "Africa/Abidjan", latitude: 5.36, longitude: -4.008),
        .init(city: "拉哥斯", timeZoneID: "Africa/Lagos", latitude: 6.5244, longitude: 3.3792),
        .init(city: "馬普托", timeZoneID: "Africa/Maputo", latitude: -25.9692, longitude: 32.5732),
        .init(city: "奈洛比", timeZoneID: "Africa/Nairobi", latitude: -1.2864, longitude: 36.8172),
        .init(city: "杜拜", timeZoneID: "Asia/Dubai", latitude: 25.2048, longitude: 55.2708),
        .init(city: "喀拉蚩", timeZoneID: "Asia/Karachi", latitude: 24.8607, longitude: 67.0011),
        .init(city: "達卡", timeZoneID: "Asia/Dhaka", latitude: 23.8103, longitude: 90.4125),
        .init(city: "曼谷", timeZoneID: "Asia/Bangkok", latitude: 13.7563, longitude: 100.5018),
        .init(city: "上海", timeZoneID: "Asia/Shanghai", latitude: 31.2304, longitude: 121.4737),
        .init(city: "東京", timeZoneID: "Asia/Tokyo", latitude: 35.6762, longitude: 139.6503),
        .init(city: "布里斯本", timeZoneID: "Australia/Brisbane", latitude: -27.4698, longitude: 153.0251),
        .init(city: "荷尼阿拉", timeZoneID: "Pacific/Guadalcanal", latitude: -9.4456, longitude: 159.9729),
        .init(city: "塔拉瓦", timeZoneID: "Pacific/Tarawa", latitude: 1.4518, longitude: 173.0305),
        .init(city: "阿皮亞", timeZoneID: "Pacific/Apia", latitude: -13.8507, longitude: -171.7514),
        .init(city: "基里地馬地島", timeZoneID: "Pacific/Kiritimati", latitude: 1.9871, longitude: -157.477)
    ]

    static func pair(at date: Date) -> (before: CrossDayPlace, after: CrossDayPlace)? {
        guard let before = all.first(where: { $0.hour(at: date) == 23 }),
              let after = all.first(where: { $0.hour(at: date) == 0 }) else { return nil }
        return (before, after)
    }
}

struct CrossDayToolView: View {
    @Environment(\.dismiss) private var dismiss
    let onSimulate: (CLLocationCoordinate2D) -> Void

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ToolSheetHeader(
                            title: "跨日捷徑",
                            subtitle: "依現在時間自動挑選 23:xx 與 00:xx 的城市。"
                        )

                        if let pair = CrossDayPlaces.pair(at: context.date) {
                            crossDayCard(
                                title: "即將跨日",
                                symbol: "moon.stars.fill",
                                place: pair.before,
                                date: context.date,
                                colors: [.indigo, .purple]
                            )

                            crossDayCard(
                                title: "已經跨日",
                                symbol: "sun.max.fill",
                                place: pair.after,
                                date: context.date,
                                colors: [.orange, .pink]
                            )
                        } else {
                            ContentUnavailableView("暫時找不到跨日時區", systemImage: "globe")
                        }

                        Text("固定 GPS 後，如需同步日期，請到 iPhone「設定 → 一般 → 日期與時間」搜尋卡片上的城市或時區。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("跨日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
        }
    }

    private func crossDayCard(
        title: String,
        symbol: String,
        place: CrossDayPlace,
        date: Date,
        colors: [Color]
    ) -> some View {
        Button {
            dismiss()
            onSimulate(place.coordinate)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(title, systemImage: symbol)
                        .font(.headline)
                    Spacer()
                    Text(place.utcText(at: date))
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.18), in: Capsule())
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.city)
                            .font(.title2.bold())
                        Text(place.timeZoneID)
                            .font(.caption)
                            .opacity(0.85)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(place.timeText(at: date))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(place.dateText(at: date))
                            .font(.caption.monospacedDigit())
                    }
                }

                HStack {
                    Image(systemName: "location.fill")
                    Text("固定 GPS 到這裡")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .shadow(color: colors[0].opacity(0.25), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(place.city)，\(place.timeText(at: date))，固定 GPS")
    }
}
