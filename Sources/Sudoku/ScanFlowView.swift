import PhotosUI
import SudokuCore
import SwiftUI
import UIKit

/// Scan a puzzle from a photo: choose a source, let the app read the grid, fix any
/// misreads on the editable review screen, then play it.
struct ScanFlowView: View {
    let onStart: (_ puzzle: [Int], _ solution: [Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isWorking = false
    @State private var message: String?

    // Review state
    @State private var digits: [Int]?
    @State private var uncertain: Set<Int> = []
    @State private var selected: Int?
    @State private var analysis: PuzzleCheck.Analysis?
    @State private var note: String?

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        NavigationStack {
            Group {
                if isWorking {
                    VStack(spacing: 14) {
                        ProgressView().controlSize(.large)
                        Text("Reading the puzzle…").foregroundStyle(.secondary)
                    }
                } else if digits != nil {
                    review
                } else {
                    source
                }
            }
            .navigationTitle("Scan a Puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if digits != nil && !isWorking {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Rescan") { reset() }
                    }
                }
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await process(data)
                } else {
                    message = "Couldn't load that photo."
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                Task { await process(data) }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Choosing a source

    private var source: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 54))
                    .foregroundStyle(theme.accent)
                    .padding(.top, 20)
                Text("Photograph a Sudoku from a newspaper, book or screen. The app finds the grid and reads the numbers on your device. Nothing is uploaded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Tip: fill the frame with the grid, keep it flat and well lit. You can fix any misread numbers before playing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let message {
                    Text(message).font(.footnote).foregroundStyle(.red)
                }

                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        if cameraAvailable {
                            sourceButton("Take a photo", "camera.fill") { showCamera = true }
                        }
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            SourceRow(title: "Choose from library", icon: "photo.on.rectangle")
                        }
                        .buttonStyle(.plain)
                        sourceButton("Try with a sample puzzle", "testtube.2") { runSample() }
                    }
                }
                .padding(.top, 6)
            }
            .padding()
        }
    }

    private func sourceButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { SourceRow(title: title, icon: icon) }
            .buttonStyle(.plain)
    }

    // MARK: Review

    private var review: some View {
        let board = digits ?? []
        return ScrollView {
            VStack(spacing: 14) {
                if let note {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                MiniBoard(
                    puzzle: board, values: board,
                    onTap: { selected = $0 },
                    selected: selected,
                    conflicts: analysis?.conflicts ?? [],
                    uncertain: uncertain
                )

                statusView

                digitPad

                Button(action: start) {
                    Label("Play this puzzle", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(!canStart)
            }
            .padding()
        }
    }

    private var canStart: Bool {
        if case .valid = analysis?.status { return true }
        return false
    }

    @ViewBuilder
    private var statusView: some View {
        let (text, icon, color) = statusInfo
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.subheadline)
            Spacer()
            if let a = analysis { Text("\(a.clues) clues").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassSurface(RoundedRectangle(cornerRadius: 14, style: .continuous), interactive: false)
    }

    private var statusInfo: (String, String, Color) {
        guard let a = analysis else { return ("Checking…", "hourglass", .secondary) }
        switch a.status {
        case .valid: return ("Valid puzzle with exactly one solution.", "checkmark.circle.fill", .green)
        case .conflicts: return ("Red cells clash with each other. Fix them to continue.", "exclamationmark.triangle.fill", .red)
        case .noSolution: return ("This puzzle has no solution. Check the numbers.", "xmark.circle.fill", .red)
        case .multipleSolutions: return ("More than one solution. A number is probably missing.", "exclamationmark.circle.fill", .orange)
        case .tooFewClues(let n): return ("Only \(n) numbers read. A puzzle needs at least \(PuzzleCheck.minimumClues).", "exclamationmark.circle.fill", .orange)
        }
    }

    private var digitPad: some View {
        VStack(spacing: 8) {
            Text(selected == nil ? "Tap a cell to correct it (yellow = unsure)." : "Choose the number for the selected cell.")
                .font(.caption)
                .foregroundStyle(.secondary)
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(1...9, id: \.self) { n in
                        Button { set(n) } label: {
                            Text("\(n)").font(.title3)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .foregroundStyle(.primary)
                                .glassSurface(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    Button { set(0) } label: {
                        Image(systemName: "delete.left")
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .foregroundStyle(.primary)
                            .glassSurface(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(selected == nil)
            .opacity(selected == nil ? 0.5 : 1)
        }
    }

    // MARK: Actions

    private func set(_ n: Int) {
        guard let s = selected, digits != nil else { return }
        digits?[s] = n
        uncertain.remove(s)
        refreshAnalysis()
    }

    private func refreshAnalysis() {
        guard let d = digits else { return }
        analysis = PuzzleCheck.analyze(d)
    }

    private func reset() {
        digits = nil
        uncertain = []
        selected = nil
        analysis = nil
        note = nil
        message = nil
    }

    private func start() {
        guard let d = digits, case .valid(let solution) = analysis?.status else { return }
        dismiss()
        onStart(d, solution)
    }

    private func process(_ data: Data) async {
        message = nil
        isWorking = true
        defer { isWorking = false }
        guard let result = await ScanService.scan(imageData: data) else {
            message = "Couldn't read that image. Try another photo."
            return
        }
        show(result, extra: nil)
    }

    private func show(_ result: ScanService.Result, extra: String?) {
        digits = result.digits
        uncertain = result.uncertain
        selected = nil
        var parts: [String] = []
        if let extra { parts.append(extra) }
        if !result.foundGrid { parts.append("No square grid was found, so the middle of the photo was used. Try a closer, flatter shot if the numbers look wrong.") }
        if !result.uncertain.isEmpty { parts.append("\(result.uncertain.count) cell\(result.uncertain.count == 1 ? "" : "s") marked yellow need checking.") }
        note = parts.isEmpty ? nil : parts.joined(separator: " ")
        refreshAnalysis()
    }

    /// Renders a known puzzle to an image and scans it, so you can see how well reading works.
    private func runSample() {
        let (puzzle, _) = SudokuEngine.generate(.easy)
        guard let data = SamplePuzzleImage.pngData(for: puzzle) else {
            message = "Couldn't create the sample image."
            return
        }
        Task {
            message = nil
            isWorking = true
            defer { isWorking = false }
            guard let result = await ScanService.scan(imageData: data) else {
                message = "The sample scan failed."
                return
            }
            let total = puzzle.filter { $0 != 0 }.count
            let correct = (0..<81).filter { puzzle[$0] != 0 && result.digits[$0] == puzzle[$0] }.count
            let extra = "Self-test: \(correct) of \(total) numbers read correctly."
            show(result, extra: extra)
        }
    }
}

/// One glass row in the source chooser. A separate view so non-isolated closures
/// (such as the photo picker's label) can create it.
private struct SourceRow: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).frame(width: 28)
            Text(title).font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .foregroundStyle(.primary)
        .glassSurface(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Camera capture via the system image picker.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                parent.onImage(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
