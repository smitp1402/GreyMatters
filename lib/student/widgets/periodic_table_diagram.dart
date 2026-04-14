// lib/student/widgets/periodic_table_diagram.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Full 118-element periodic table diagram with color-coded families.
class PeriodicTableDiagram extends StatelessWidget {
  const PeriodicTableDiagram({super.key});

  // Element families with colors
  static const _alkali = Color(0xFFEF5350);      // Group 1 (except H)
  static const _alkalineEarth = Color(0xFFFF9800); // Group 2
  static const _transition = Color(0xFF42A5F5);    // Groups 3-12
  static const _postTransition = Color(0xFF78909C); // Al, Ga, In, Sn, Tl, Pb, Bi, Nh, Fl, Mc, Lv
  static const _metalloid = Color(0xFF8D6E63);     // B, Si, Ge, As, Sb, Te
  static const _nonmetal = Color(0xFF66BB6A);      // C, N, O, P, S, Se
  static const _halogen = Color(0xFFEC407A);       // Group 17
  static const _nobleGas = Color(0xFF26A69A);      // Group 18
  static const _lanthanide = Color(0xFFAB47BC);    // La-Lu
  static const _actinide = Color(0xFF7E57C2);      // Ac-Lr
  static const _hydrogen = Color(0xFFE0E0E0);

  // Full element data: [symbol, atomicNumber, color, period, group]
  // period/group = position on the standard 18-column table
  static final List<_El> _elements = [
    // Period 1
    _El('H', 1, _hydrogen, 1, 1),
    _El('He', 2, _nobleGas, 1, 18),
    // Period 2
    _El('Li', 3, _alkali, 2, 1), _El('Be', 4, _alkalineEarth, 2, 2),
    _El('B', 5, _metalloid, 2, 13), _El('C', 6, _nonmetal, 2, 14),
    _El('N', 7, _nonmetal, 2, 15), _El('O', 8, _nonmetal, 2, 16),
    _El('F', 9, _halogen, 2, 17), _El('Ne', 10, _nobleGas, 2, 18),
    // Period 3
    _El('Na', 11, _alkali, 3, 1), _El('Mg', 12, _alkalineEarth, 3, 2),
    _El('Al', 13, _postTransition, 3, 13), _El('Si', 14, _metalloid, 3, 14),
    _El('P', 15, _nonmetal, 3, 15), _El('S', 16, _nonmetal, 3, 16),
    _El('Cl', 17, _halogen, 3, 17), _El('Ar', 18, _nobleGas, 3, 18),
    // Period 4
    _El('K', 19, _alkali, 4, 1), _El('Ca', 20, _alkalineEarth, 4, 2),
    _El('Sc', 21, _transition, 4, 3), _El('Ti', 22, _transition, 4, 4),
    _El('V', 23, _transition, 4, 5), _El('Cr', 24, _transition, 4, 6),
    _El('Mn', 25, _transition, 4, 7), _El('Fe', 26, _transition, 4, 8),
    _El('Co', 27, _transition, 4, 9), _El('Ni', 28, _transition, 4, 10),
    _El('Cu', 29, _transition, 4, 11), _El('Zn', 30, _transition, 4, 12),
    _El('Ga', 31, _postTransition, 4, 13), _El('Ge', 32, _metalloid, 4, 14),
    _El('As', 33, _metalloid, 4, 15), _El('Se', 34, _nonmetal, 4, 16),
    _El('Br', 35, _halogen, 4, 17), _El('Kr', 36, _nobleGas, 4, 18),
    // Period 5
    _El('Rb', 37, _alkali, 5, 1), _El('Sr', 38, _alkalineEarth, 5, 2),
    _El('Y', 39, _transition, 5, 3), _El('Zr', 40, _transition, 5, 4),
    _El('Nb', 41, _transition, 5, 5), _El('Mo', 42, _transition, 5, 6),
    _El('Tc', 43, _transition, 5, 7), _El('Ru', 44, _transition, 5, 8),
    _El('Rh', 45, _transition, 5, 9), _El('Pd', 46, _transition, 5, 10),
    _El('Ag', 47, _transition, 5, 11), _El('Cd', 48, _transition, 5, 12),
    _El('In', 49, _postTransition, 5, 13), _El('Sn', 50, _postTransition, 5, 14),
    _El('Sb', 51, _metalloid, 5, 15), _El('Te', 52, _metalloid, 5, 16),
    _El('I', 53, _halogen, 5, 17), _El('Xe', 54, _nobleGas, 5, 18),
    // Period 6
    _El('Cs', 55, _alkali, 6, 1), _El('Ba', 56, _alkalineEarth, 6, 2),
    // La-Lu go to lanthanide row
    _El('Hf', 72, _transition, 6, 4), _El('Ta', 73, _transition, 6, 5),
    _El('W', 74, _transition, 6, 6), _El('Re', 75, _transition, 6, 7),
    _El('Os', 76, _transition, 6, 8), _El('Ir', 77, _transition, 6, 9),
    _El('Pt', 78, _transition, 6, 10), _El('Au', 79, _transition, 6, 11),
    _El('Hg', 80, _transition, 6, 12), _El('Tl', 81, _postTransition, 6, 13),
    _El('Pb', 82, _postTransition, 6, 14), _El('Bi', 83, _postTransition, 6, 15),
    _El('Po', 84, _postTransition, 6, 16), _El('At', 85, _halogen, 6, 17),
    _El('Rn', 86, _nobleGas, 6, 18),
    // Period 7
    _El('Fr', 87, _alkali, 7, 1), _El('Ra', 88, _alkalineEarth, 7, 2),
    // Ac-Lr go to actinide row
    _El('Rf', 104, _transition, 7, 4), _El('Db', 105, _transition, 7, 5),
    _El('Sg', 106, _transition, 7, 6), _El('Bh', 107, _transition, 7, 7),
    _El('Hs', 108, _transition, 7, 8), _El('Mt', 109, _transition, 7, 9),
    _El('Ds', 110, _transition, 7, 10), _El('Rg', 111, _transition, 7, 11),
    _El('Cn', 112, _transition, 7, 12), _El('Nh', 113, _postTransition, 7, 13),
    _El('Fl', 114, _postTransition, 7, 14), _El('Mc', 115, _postTransition, 7, 15),
    _El('Lv', 116, _postTransition, 7, 16), _El('Ts', 117, _halogen, 7, 17),
    _El('Og', 118, _nobleGas, 7, 18),
  ];

  // Lanthanide placeholder in period 6 group 3
  static const _lanPlaceholder = _El('*', 0, _lanthanide, 6, 3);
  // Actinide placeholder in period 7 group 3
  static const _actPlaceholder = _El('**', 0, _actinide, 7, 3);

  // Lanthanides (period 8 in our layout = row below main table)
  static final List<_El> _lanthanides = [
    _El('La', 57, _lanthanide, 9, 3), _El('Ce', 58, _lanthanide, 9, 4),
    _El('Pr', 59, _lanthanide, 9, 5), _El('Nd', 60, _lanthanide, 9, 6),
    _El('Pm', 61, _lanthanide, 9, 7), _El('Sm', 62, _lanthanide, 9, 8),
    _El('Eu', 63, _lanthanide, 9, 9), _El('Gd', 64, _lanthanide, 9, 10),
    _El('Tb', 65, _lanthanide, 9, 11), _El('Dy', 66, _lanthanide, 9, 12),
    _El('Ho', 67, _lanthanide, 9, 13), _El('Er', 68, _lanthanide, 9, 14),
    _El('Tm', 69, _lanthanide, 9, 15), _El('Yb', 70, _lanthanide, 9, 16),
    _El('Lu', 71, _lanthanide, 9, 17),
  ];

  // Actinides
  static final List<_El> _actinides = [
    _El('Ac', 89, _actinide, 10, 3), _El('Th', 90, _actinide, 10, 4),
    _El('Pa', 91, _actinide, 10, 5), _El('U', 92, _actinide, 10, 6),
    _El('Np', 93, _actinide, 10, 7), _El('Pu', 94, _actinide, 10, 8),
    _El('Am', 95, _actinide, 10, 9), _El('Cm', 96, _actinide, 10, 10),
    _El('Bk', 97, _actinide, 10, 11), _El('Cf', 98, _actinide, 10, 12),
    _El('Es', 99, _actinide, 10, 13), _El('Fm', 100, _actinide, 10, 14),
    _El('Md', 101, _actinide, 10, 15), _El('No', 102, _actinide, 10, 16),
    _El('Lr', 103, _actinide, 10, 17),
  ];

  @override
  Widget build(BuildContext context) {
    // Build lookup map
    final Map<String, _El> grid = {};
    for (final el in _elements) {
      grid['${el.period},${el.group}'] = el;
    }
    grid['6,3'] = _lanPlaceholder;
    grid['7,3'] = _actPlaceholder;

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
        _buildSpecialRow('*', _lanthanides),
        const SizedBox(height: 2),

        // Actinides row
        _buildSpecialRow('**', _actinides),

        const SizedBox(height: 14),

        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _leg(_alkali, 'Alkali'),
            _leg(_alkalineEarth, 'Alk. Earth'),
            _leg(_transition, 'Transition'),
            _leg(_postTransition, 'Post-Trans.'),
            _leg(_metalloid, 'Metalloid'),
            _leg(_nonmetal, 'Nonmetal'),
            _leg(_halogen, 'Halogen'),
            _leg(_nobleGas, 'Noble Gas'),
            _leg(_lanthanide, 'Lanthanide'),
            _leg(_actinide, 'Actinide'),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(int period, Map<String, _El> grid) {
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

  Widget _buildSpecialRow(String label, List<_El> elements) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(label,
                style: TextStyle(fontFamily: 'Consolas', fontSize: 7,
                    color: elements.first.color.withValues(alpha: 0.5)),
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

  Widget _buildCell(_El el) {
    return AspectRatio(
      aspectRatio: 1,
      child: Tooltip(
        message: el.num > 0 ? '${el.symbol} (${el.num})' : el.symbol,
        child: Container(
          margin: const EdgeInsets.all(0.5),
          decoration: BoxDecoration(
            color: el.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(1.5),
            border: Border.all(color: el.color.withValues(alpha: 0.25), width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (el.num > 0)
                Text('${el.num}',
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 5,
                        color: el.color.withValues(alpha: 0.5))),
              Text(el.symbol,
                  style: TextStyle(fontFamily: 'Consolas',
                      fontSize: el.symbol.length > 2 ? 6 : 8,
                      fontWeight: FontWeight.w700, color: el.color)),
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

class _El {
  final String symbol;
  final int num;
  final Color color;
  final int period;
  final int group;
  const _El(this.symbol, this.num, this.color, this.period, this.group);
}
