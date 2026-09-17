import UIKit

/// The wrecking-ball scene's ground: a pale drafting sheet with a fine
/// grid and a heavier line every fourth cell.
final class BlueprintBackgroundView: UIView {

    private let gradient = CAGradientLayer()
    private let fineGrid = CAShapeLayer()
    private let coarseGrid = CAShapeLayer()
    /// Fine cells per coarse one.
    private let coarseEvery = 4
    private let columns = 12

    init(frame: CGRect, top: UIColor, bottom: UIColor, line: UIColor) {
        super.init(frame: frame)
        gradient.colors = [top.cgColor, bottom.cgColor]
        gradient.startPoint = CGPoint(x: 0.1, y: 0)
        gradient.endPoint = CGPoint(x: 0.9, y: 1)
        layer.addSublayer(gradient)

        fineGrid.lineWidth = 0.5
        coarseGrid.lineWidth = 1
        for grid in [fineGrid, coarseGrid] {
            grid.strokeColor = line.cgColor
            grid.fillColor = nil
            layer.addSublayer(grid)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds

        let cell = bounds.width / CGFloat(columns)
        guard cell > 0 else { return }
        let fine = UIBezierPath()
        let coarse = UIBezierPath()
        for index in 0...Int(bounds.width / cell) {
            let path = index.isMultiple(of: coarseEvery) ? coarse : fine
            path.move(to: CGPoint(x: CGFloat(index) * cell, y: 0))
            path.addLine(to: CGPoint(x: CGFloat(index) * cell, y: bounds.height))
        }
        for index in 0...Int(bounds.height / cell) {
            let path = index.isMultiple(of: coarseEvery) ? coarse : fine
            path.move(to: CGPoint(x: 0, y: CGFloat(index) * cell))
            path.addLine(to: CGPoint(x: bounds.width, y: CGFloat(index) * cell))
        }
        fineGrid.path = fine.cgPath
        coarseGrid.path = coarse.cgPath
    }
}
