// lib/student/widgets/periodic_table_diagram.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/models/element_data.dart';

/// Full 118-element periodic table diagram with color-coded families.
class PeriodicTableDiagram extends StatelessWidget {
  const PeriodicTableDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    // Build lookup map: "period,group" → element
    final Map<String, ChemicalElement> grid = {};
    for (final el in allElements) {
      // Main table elements (periods 1-7)
      if (el.period <= 7) {
        grid['${el.period},${el.group}'] = el;
      }
    }

    // Lanthanide/actinide placeholders in main table
    final lanPlaceholder = ChemicalElement(
      symbol: '*', name: 'Lanthanides', atomicNumber: 0, atomicMass: 0,
      family: ElementFamily.lanthanide, period: 6, group: 3,
    );
    final actPlaceholder = ChemicalElement(
      symbol: '**', name: 'Actinides', atomicNumber: 0, atomicMass: 0,
      family: ElementFamily.actinide, period: 7, group: 3,
    );
    grid['6,3'] = lanPlaceholder;
    grid['7,3'] = actPlaceholder;

    // Separate lanthanides and actinides for special rows
    final lanthanides = allElements.where((e) => e.period == 9).toList();
    final actinides = allElements.where((e) => e.period == 10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group numbers
        Row(
          children: [
            const SizedBox(width: 20),
            ...List.generate(18, (g) => Expanded(
                  child: Center(
                    child: Text('${g + 1}',
                        style: TextStyle(fontFamily: 'Consolas', fontSize: 7,
                            color: AppColors.outline.withValues(alpha: 0.4))),
                  ),
                )),
          ],
        ),
        const SizedBox(height: 2),

        // Main table (periods 1-7)
        ...List.generate(7, (p) => _buildRow(p + 1, grid)),

        // Gap
        const SizedBox(height: 8),

        // Lanthanides row
        _buildSpecialRow('*', lanthanides),
        const SizedBox(height: 2),

        // Actinides row
        _buildSpecialRow('**', actinides),

        const SizedBox(height: 14),

        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _leg(familyColor(ElementFamily.alkali), 'Alkali'),
            _leg(familyColor(ElementFamily.alkalineEarth), 'Alk. Earth'),
            _leg(familyColor(ElementFamily.transition), 'Transition'),
            _leg(familyColor(ElementFamily.postTransition), 'Post-Trans.'),
            _leg(familyColor(ElementFamily.metalloid), 'Metalloid'),
            _leg(familyColor(ElementFamily.nonmetal), 'Nonmetal'),
            _leg(familyColor(ElementFamily.halogen), 'Halogen'),
            _leg(familyColor(ElementFamily.nobleGas), 'Noble Gas'),
            _leg(familyColor(ElementFamily.lanthanide), 'Lanthanide'),
            _leg(familyColor(ElementFamily.actinide), 'Actinide'),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(int period, Map<String, ChemicalElement> grid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('$period',
                style: TextStyle(fontFamily: 'Consolas', fontSize: 8,
                    color: AppColors.outline.withValues(alpha: 0.4)),
                textAlign: TextAlign.center),
          ),
          ...List.generate(18, (g) {
            final el = grid['$period,${g + 1}'];
            if (el == null) {
              return Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(margin: const EdgeInsets.all(0.5)),
                ),
              );
            }
            return Expanded(child: _buildCell(el));
          }),
        ],
      ),
    );
  }

  Widget _buildSpecialRow(String label, List<ChemicalElement> elements) {
    final color = familyColor(elements.first.family);
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(label,
                style: TextStyle(fontFamily: 'Consolas', fontSize: 7,
                    color: color.withValues(alpha: 0.5)),
                textAlign: TextAlign.center),
          ),
          // Empty space for groups 1-2
          const Expanded(child: SizedBox()),
          const Expanded(child: SizedBox()),
          // 15 lanthanide/actinide elements in groups 3-17
          ...elements.map((el) => Expanded(child: _buildCell(el))),
          // Empty space for group 18
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildCell(ChemicalElement el) {
    final color = familyColor(el.family);
    return AspectRatio(
      aspectRatio: 1,
      child: Tooltip(
        message: el.atomicNumber > 0 ? '${el.symbol} (${el.atomicNumber})' : el.symbol,
        child: Container(
          margin: const EdgeInsets.all(0.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(1.5),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (el.atomicNumber > 0)
                Text('${el.atomicNumber}',
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 5,
                        color: color.withValues(alpha: 0.5))),
              Text(el.symbol,
                  style: TextStyle(fontFamily: 'Consolas',
                      fontSize: el.symbol.length > 2 ? 6 : 8,
                      fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leg(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontFamily: 'Consolas', fontSize: 8,
            color: AppColors.outline.withValues(alpha: 0.7))),
      ],
    );
  }
}
