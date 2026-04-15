// lib/core/models/element_data.dart

// Shared element dataset for the entire app — periodic table diagram,
// Synthetic Alchemist game, and future activities.

import 'package:flutter/material.dart';

// ── Element family classification ───────────────────────────────────────

enum ElementFamily {
  hydrogen,
  alkali,
  alkalineEarth,
  transition,
  postTransition,
  metalloid,
  nonmetal,
  halogen,
  nobleGas,
  lanthanide,
  actinide,
}

Color familyColor(ElementFamily family) {
  switch (family) {
    case ElementFamily.hydrogen:
      return const Color(0xFFE0E0E0);
    case ElementFamily.alkali:
      return const Color(0xFFEF5350);
    case ElementFamily.alkalineEarth:
      return const Color(0xFFFF9800);
    case ElementFamily.transition:
      return const Color(0xFF42A5F5);
    case ElementFamily.postTransition:
      return const Color(0xFF78909C);
    case ElementFamily.metalloid:
      return const Color(0xFF8D6E63);
    case ElementFamily.nonmetal:
      return const Color(0xFF66BB6A);
    case ElementFamily.halogen:
      return const Color(0xFFEC407A);
    case ElementFamily.nobleGas:
      return const Color(0xFF26A69A);
    case ElementFamily.lanthanide:
      return const Color(0xFFAB47BC);
    case ElementFamily.actinide:
      return const Color(0xFF7E57C2);
  }
}

// ── Chemical element model ──────────────────────────────────────────────

class ChemicalElement {
  final String symbol;
  final String name;
  final int atomicNumber;
  final double atomicMass;
  final ElementFamily family;
  final int period; // 1-7 main, 9=lanthanide row, 10=actinide row (for diagram layout)
  final int group;  // 1-18

  const ChemicalElement({
    required this.symbol,
    required this.name,
    required this.atomicNumber,
    required this.atomicMass,
    required this.family,
    required this.period,
    required this.group,
  });
}

// ── All 118 elements ────────────────────────────────────────────────────

const List<ChemicalElement> allElements = [
  // Period 1
  ChemicalElement(symbol: 'H',  name: 'Hydrogen',      atomicNumber: 1,   atomicMass: 1.008,   family: ElementFamily.hydrogen,       period: 1, group: 1),
  ChemicalElement(symbol: 'He', name: 'Helium',         atomicNumber: 2,   atomicMass: 4.003,   family: ElementFamily.nobleGas,       period: 1, group: 18),
  // Period 2
  ChemicalElement(symbol: 'Li', name: 'Lithium',        atomicNumber: 3,   atomicMass: 6.941,   family: ElementFamily.alkali,          period: 2, group: 1),
  ChemicalElement(symbol: 'Be', name: 'Beryllium',      atomicNumber: 4,   atomicMass: 9.012,   family: ElementFamily.alkalineEarth,   period: 2, group: 2),
  ChemicalElement(symbol: 'B',  name: 'Boron',          atomicNumber: 5,   atomicMass: 10.81,   family: ElementFamily.metalloid,       period: 2, group: 13),
  ChemicalElement(symbol: 'C',  name: 'Carbon',         atomicNumber: 6,   atomicMass: 12.011,  family: ElementFamily.nonmetal,        period: 2, group: 14),
  ChemicalElement(symbol: 'N',  name: 'Nitrogen',       atomicNumber: 7,   atomicMass: 14.007,  family: ElementFamily.nonmetal,        period: 2, group: 15),
  ChemicalElement(symbol: 'O',  name: 'Oxygen',         atomicNumber: 8,   atomicMass: 15.999,  family: ElementFamily.nonmetal,        period: 2, group: 16),
  ChemicalElement(symbol: 'F',  name: 'Fluorine',       atomicNumber: 9,   atomicMass: 18.998,  family: ElementFamily.halogen,         period: 2, group: 17),
  ChemicalElement(symbol: 'Ne', name: 'Neon',           atomicNumber: 10,  atomicMass: 20.180,  family: ElementFamily.nobleGas,        period: 2, group: 18),
  // Period 3
  ChemicalElement(symbol: 'Na', name: 'Sodium',         atomicNumber: 11,  atomicMass: 22.990,  family: ElementFamily.alkali,          period: 3, group: 1),
  ChemicalElement(symbol: 'Mg', name: 'Magnesium',      atomicNumber: 12,  atomicMass: 24.305,  family: ElementFamily.alkalineEarth,   period: 3, group: 2),
  ChemicalElement(symbol: 'Al', name: 'Aluminium',      atomicNumber: 13,  atomicMass: 26.982,  family: ElementFamily.postTransition,  period: 3, group: 13),
  ChemicalElement(symbol: 'Si', name: 'Silicon',        atomicNumber: 14,  atomicMass: 28.086,  family: ElementFamily.metalloid,       period: 3, group: 14),
  ChemicalElement(symbol: 'P',  name: 'Phosphorus',     atomicNumber: 15,  atomicMass: 30.974,  family: ElementFamily.nonmetal,        period: 3, group: 15),
  ChemicalElement(symbol: 'S',  name: 'Sulfur',         atomicNumber: 16,  atomicMass: 32.06,   family: ElementFamily.nonmetal,        period: 3, group: 16),
  ChemicalElement(symbol: 'Cl', name: 'Chlorine',       atomicNumber: 17,  atomicMass: 35.45,   family: ElementFamily.halogen,         period: 3, group: 17),
  ChemicalElement(symbol: 'Ar', name: 'Argon',          atomicNumber: 18,  atomicMass: 39.948,  family: ElementFamily.nobleGas,        period: 3, group: 18),
  // Period 4
  ChemicalElement(symbol: 'K',  name: 'Potassium',      atomicNumber: 19,  atomicMass: 39.098,  family: ElementFamily.alkali,          period: 4, group: 1),
  ChemicalElement(symbol: 'Ca', name: 'Calcium',        atomicNumber: 20,  atomicMass: 40.078,  family: ElementFamily.alkalineEarth,   period: 4, group: 2),
  ChemicalElement(symbol: 'Sc', name: 'Scandium',       atomicNumber: 21,  atomicMass: 44.956,  family: ElementFamily.transition,      period: 4, group: 3),
  ChemicalElement(symbol: 'Ti', name: 'Titanium',       atomicNumber: 22,  atomicMass: 47.867,  family: ElementFamily.transition,      period: 4, group: 4),
  ChemicalElement(symbol: 'V',  name: 'Vanadium',       atomicNumber: 23,  atomicMass: 50.942,  family: ElementFamily.transition,      period: 4, group: 5),
  ChemicalElement(symbol: 'Cr', name: 'Chromium',       atomicNumber: 24,  atomicMass: 51.996,  family: ElementFamily.transition,      period: 4, group: 6),
  ChemicalElement(symbol: 'Mn', name: 'Manganese',      atomicNumber: 25,  atomicMass: 54.938,  family: ElementFamily.transition,      period: 4, group: 7),
  ChemicalElement(symbol: 'Fe', name: 'Iron',           atomicNumber: 26,  atomicMass: 55.845,  family: ElementFamily.transition,      period: 4, group: 8),
  ChemicalElement(symbol: 'Co', name: 'Cobalt',         atomicNumber: 27,  atomicMass: 58.933,  family: ElementFamily.transition,      period: 4, group: 9),
  ChemicalElement(symbol: 'Ni', name: 'Nickel',         atomicNumber: 28,  atomicMass: 58.693,  family: ElementFamily.transition,      period: 4, group: 10),
  ChemicalElement(symbol: 'Cu', name: 'Copper',         atomicNumber: 29,  atomicMass: 63.546,  family: ElementFamily.transition,      period: 4, group: 11),
  ChemicalElement(symbol: 'Zn', name: 'Zinc',           atomicNumber: 30,  atomicMass: 65.38,   family: ElementFamily.transition,      period: 4, group: 12),
  ChemicalElement(symbol: 'Ga', name: 'Gallium',        atomicNumber: 31,  atomicMass: 69.723,  family: ElementFamily.postTransition,  period: 4, group: 13),
  ChemicalElement(symbol: 'Ge', name: 'Germanium',      atomicNumber: 32,  atomicMass: 72.630,  family: ElementFamily.metalloid,       period: 4, group: 14),
  ChemicalElement(symbol: 'As', name: 'Arsenic',        atomicNumber: 33,  atomicMass: 74.922,  family: ElementFamily.metalloid,       period: 4, group: 15),
  ChemicalElement(symbol: 'Se', name: 'Selenium',       atomicNumber: 34,  atomicMass: 78.971,  family: ElementFamily.nonmetal,        period: 4, group: 16),
  ChemicalElement(symbol: 'Br', name: 'Bromine',        atomicNumber: 35,  atomicMass: 79.904,  family: ElementFamily.halogen,         period: 4, group: 17),
  ChemicalElement(symbol: 'Kr', name: 'Krypton',        atomicNumber: 36,  atomicMass: 83.798,  family: ElementFamily.nobleGas,        period: 4, group: 18),
  // Period 5
  ChemicalElement(symbol: 'Rb', name: 'Rubidium',       atomicNumber: 37,  atomicMass: 85.468,  family: ElementFamily.alkali,          period: 5, group: 1),
  ChemicalElement(symbol: 'Sr', name: 'Strontium',      atomicNumber: 38,  atomicMass: 87.62,   family: ElementFamily.alkalineEarth,   period: 5, group: 2),
  ChemicalElement(symbol: 'Y',  name: 'Yttrium',        atomicNumber: 39,  atomicMass: 88.906,  family: ElementFamily.transition,      period: 5, group: 3),
  ChemicalElement(symbol: 'Zr', name: 'Zirconium',      atomicNumber: 40,  atomicMass: 91.224,  family: ElementFamily.transition,      period: 5, group: 4),
  ChemicalElement(symbol: 'Nb', name: 'Niobium',        atomicNumber: 41,  atomicMass: 92.906,  family: ElementFamily.transition,      period: 5, group: 5),
  ChemicalElement(symbol: 'Mo', name: 'Molybdenum',     atomicNumber: 42,  atomicMass: 95.95,   family: ElementFamily.transition,      period: 5, group: 6),
  ChemicalElement(symbol: 'Tc', name: 'Technetium',     atomicNumber: 43,  atomicMass: 98.0,    family: ElementFamily.transition,      period: 5, group: 7),
  ChemicalElement(symbol: 'Ru', name: 'Ruthenium',      atomicNumber: 44,  atomicMass: 101.07,  family: ElementFamily.transition,      period: 5, group: 8),
  ChemicalElement(symbol: 'Rh', name: 'Rhodium',        atomicNumber: 45,  atomicMass: 102.906, family: ElementFamily.transition,      period: 5, group: 9),
  ChemicalElement(symbol: 'Pd', name: 'Palladium',      atomicNumber: 46,  atomicMass: 106.42,  family: ElementFamily.transition,      period: 5, group: 10),
  ChemicalElement(symbol: 'Ag', name: 'Silver',         atomicNumber: 47,  atomicMass: 107.868, family: ElementFamily.transition,      period: 5, group: 11),
  ChemicalElement(symbol: 'Cd', name: 'Cadmium',        atomicNumber: 48,  atomicMass: 112.414, family: ElementFamily.transition,      period: 5, group: 12),
  ChemicalElement(symbol: 'In', name: 'Indium',         atomicNumber: 49,  atomicMass: 114.818, family: ElementFamily.postTransition,  period: 5, group: 13),
  ChemicalElement(symbol: 'Sn', name: 'Tin',            atomicNumber: 50,  atomicMass: 118.710, family: ElementFamily.postTransition,  period: 5, group: 14),
  ChemicalElement(symbol: 'Sb', name: 'Antimony',       atomicNumber: 51,  atomicMass: 121.760, family: ElementFamily.metalloid,       period: 5, group: 15),
  ChemicalElement(symbol: 'Te', name: 'Tellurium',      atomicNumber: 52,  atomicMass: 127.60,  family: ElementFamily.metalloid,       period: 5, group: 16),
  ChemicalElement(symbol: 'I',  name: 'Iodine',         atomicNumber: 53,  atomicMass: 126.904, family: ElementFamily.halogen,         period: 5, group: 17),
  ChemicalElement(symbol: 'Xe', name: 'Xenon',          atomicNumber: 54,  atomicMass: 131.293, family: ElementFamily.nobleGas,        period: 5, group: 18),
  // Period 6
  ChemicalElement(symbol: 'Cs', name: 'Caesium',        atomicNumber: 55,  atomicMass: 132.905, family: ElementFamily.alkali,          period: 6, group: 1),
  ChemicalElement(symbol: 'Ba', name: 'Barium',         atomicNumber: 56,  atomicMass: 137.327, family: ElementFamily.alkalineEarth,   period: 6, group: 2),
  // Lanthanides (57-71)
  ChemicalElement(symbol: 'La', name: 'Lanthanum',      atomicNumber: 57,  atomicMass: 138.905, family: ElementFamily.lanthanide,      period: 9, group: 3),
  ChemicalElement(symbol: 'Ce', name: 'Cerium',         atomicNumber: 58,  atomicMass: 140.116, family: ElementFamily.lanthanide,      period: 9, group: 4),
  ChemicalElement(symbol: 'Pr', name: 'Praseodymium',   atomicNumber: 59,  atomicMass: 140.908, family: ElementFamily.lanthanide,      period: 9, group: 5),
  ChemicalElement(symbol: 'Nd', name: 'Neodymium',      atomicNumber: 60,  atomicMass: 144.242, family: ElementFamily.lanthanide,      period: 9, group: 6),
  ChemicalElement(symbol: 'Pm', name: 'Promethium',     atomicNumber: 61,  atomicMass: 145.0,   family: ElementFamily.lanthanide,      period: 9, group: 7),
  ChemicalElement(symbol: 'Sm', name: 'Samarium',       atomicNumber: 62,  atomicMass: 150.36,  family: ElementFamily.lanthanide,      period: 9, group: 8),
  ChemicalElement(symbol: 'Eu', name: 'Europium',       atomicNumber: 63,  atomicMass: 151.964, family: ElementFamily.lanthanide,      period: 9, group: 9),
  ChemicalElement(symbol: 'Gd', name: 'Gadolinium',     atomicNumber: 64,  atomicMass: 157.25,  family: ElementFamily.lanthanide,      period: 9, group: 10),
  ChemicalElement(symbol: 'Tb', name: 'Terbium',        atomicNumber: 65,  atomicMass: 158.925, family: ElementFamily.lanthanide,      period: 9, group: 11),
  ChemicalElement(symbol: 'Dy', name: 'Dysprosium',     atomicNumber: 66,  atomicMass: 162.500, family: ElementFamily.lanthanide,      period: 9, group: 12),
  ChemicalElement(symbol: 'Ho', name: 'Holmium',        atomicNumber: 67,  atomicMass: 164.930, family: ElementFamily.lanthanide,      period: 9, group: 13),
  ChemicalElement(symbol: 'Er', name: 'Erbium',         atomicNumber: 68,  atomicMass: 167.259, family: ElementFamily.lanthanide,      period: 9, group: 14),
  ChemicalElement(symbol: 'Tm', name: 'Thulium',        atomicNumber: 69,  atomicMass: 168.934, family: ElementFamily.lanthanide,      period: 9, group: 15),
  ChemicalElement(symbol: 'Yb', name: 'Ytterbium',      atomicNumber: 70,  atomicMass: 173.045, family: ElementFamily.lanthanide,      period: 9, group: 16),
  ChemicalElement(symbol: 'Lu', name: 'Lutetium',       atomicNumber: 71,  atomicMass: 174.967, family: ElementFamily.lanthanide,      period: 9, group: 17),
  // Back to period 6 main
  ChemicalElement(symbol: 'Hf', name: 'Hafnium',        atomicNumber: 72,  atomicMass: 178.49,  family: ElementFamily.transition,      period: 6, group: 4),
  ChemicalElement(symbol: 'Ta', name: 'Tantalum',       atomicNumber: 73,  atomicMass: 180.948, family: ElementFamily.transition,      period: 6, group: 5),
  ChemicalElement(symbol: 'W',  name: 'Tungsten',       atomicNumber: 74,  atomicMass: 183.84,  family: ElementFamily.transition,      period: 6, group: 6),
  ChemicalElement(symbol: 'Re', name: 'Rhenium',        atomicNumber: 75,  atomicMass: 186.207, family: ElementFamily.transition,      period: 6, group: 7),
  ChemicalElement(symbol: 'Os', name: 'Osmium',         atomicNumber: 76,  atomicMass: 190.23,  family: ElementFamily.transition,      period: 6, group: 8),
  ChemicalElement(symbol: 'Ir', name: 'Iridium',        atomicNumber: 77,  atomicMass: 192.217, family: ElementFamily.transition,      period: 6, group: 9),
  ChemicalElement(symbol: 'Pt', name: 'Platinum',       atomicNumber: 78,  atomicMass: 195.084, family: ElementFamily.transition,      period: 6, group: 10),
  ChemicalElement(symbol: 'Au', name: 'Gold',           atomicNumber: 79,  atomicMass: 196.967, family: ElementFamily.transition,      period: 6, group: 11),
  ChemicalElement(symbol: 'Hg', name: 'Mercury',        atomicNumber: 80,  atomicMass: 200.592, family: ElementFamily.transition,      period: 6, group: 12),
  ChemicalElement(symbol: 'Tl', name: 'Thallium',       atomicNumber: 81,  atomicMass: 204.38,  family: ElementFamily.postTransition,  period: 6, group: 13),
  ChemicalElement(symbol: 'Pb', name: 'Lead',           atomicNumber: 82,  atomicMass: 207.2,   family: ElementFamily.postTransition,  period: 6, group: 14),
  ChemicalElement(symbol: 'Bi', name: 'Bismuth',        atomicNumber: 83,  atomicMass: 208.980, family: ElementFamily.postTransition,  period: 6, group: 15),
  ChemicalElement(symbol: 'Po', name: 'Polonium',       atomicNumber: 84,  atomicMass: 209.0,   family: ElementFamily.postTransition,  period: 6, group: 16),
  ChemicalElement(symbol: 'At', name: 'Astatine',       atomicNumber: 85,  atomicMass: 210.0,   family: ElementFamily.halogen,         period: 6, group: 17),
  ChemicalElement(symbol: 'Rn', name: 'Radon',          atomicNumber: 86,  atomicMass: 222.0,   family: ElementFamily.nobleGas,        period: 6, group: 18),
  // Period 7
  ChemicalElement(symbol: 'Fr', name: 'Francium',       atomicNumber: 87,  atomicMass: 223.0,   family: ElementFamily.alkali,          period: 7, group: 1),
  ChemicalElement(symbol: 'Ra', name: 'Radium',         atomicNumber: 88,  atomicMass: 226.0,   family: ElementFamily.alkalineEarth,   period: 7, group: 2),
  // Actinides (89-103)
  ChemicalElement(symbol: 'Ac', name: 'Actinium',       atomicNumber: 89,  atomicMass: 227.0,   family: ElementFamily.actinide,        period: 10, group: 3),
  ChemicalElement(symbol: 'Th', name: 'Thorium',        atomicNumber: 90,  atomicMass: 232.038, family: ElementFamily.actinide,        period: 10, group: 4),
  ChemicalElement(symbol: 'Pa', name: 'Protactinium',   atomicNumber: 91,  atomicMass: 231.036, family: ElementFamily.actinide,        period: 10, group: 5),
  ChemicalElement(symbol: 'U',  name: 'Uranium',        atomicNumber: 92,  atomicMass: 238.029, family: ElementFamily.actinide,        period: 10, group: 6),
  ChemicalElement(symbol: 'Np', name: 'Neptunium',      atomicNumber: 93,  atomicMass: 237.0,   family: ElementFamily.actinide,        period: 10, group: 7),
  ChemicalElement(symbol: 'Pu', name: 'Plutonium',      atomicNumber: 94,  atomicMass: 244.0,   family: ElementFamily.actinide,        period: 10, group: 8),
  ChemicalElement(symbol: 'Am', name: 'Americium',      atomicNumber: 95,  atomicMass: 243.0,   family: ElementFamily.actinide,        period: 10, group: 9),
  ChemicalElement(symbol: 'Cm', name: 'Curium',         atomicNumber: 96,  atomicMass: 247.0,   family: ElementFamily.actinide,        period: 10, group: 10),
  ChemicalElement(symbol: 'Bk', name: 'Berkelium',      atomicNumber: 97,  atomicMass: 247.0,   family: ElementFamily.actinide,        period: 10, group: 11),
  ChemicalElement(symbol: 'Cf', name: 'Californium',    atomicNumber: 98,  atomicMass: 251.0,   family: ElementFamily.actinide,        period: 10, group: 12),
  ChemicalElement(symbol: 'Es', name: 'Einsteinium',    atomicNumber: 99,  atomicMass: 252.0,   family: ElementFamily.actinide,        period: 10, group: 13),
  ChemicalElement(symbol: 'Fm', name: 'Fermium',        atomicNumber: 100, atomicMass: 257.0,   family: ElementFamily.actinide,        period: 10, group: 14),
  ChemicalElement(symbol: 'Md', name: 'Mendelevium',    atomicNumber: 101, atomicMass: 258.0,   family: ElementFamily.actinide,        period: 10, group: 15),
  ChemicalElement(symbol: 'No', name: 'Nobelium',       atomicNumber: 102, atomicMass: 259.0,   family: ElementFamily.actinide,        period: 10, group: 16),
  ChemicalElement(symbol: 'Lr', name: 'Lawrencium',     atomicNumber: 103, atomicMass: 266.0,   family: ElementFamily.actinide,        period: 10, group: 17),
  // Back to period 7 main
  ChemicalElement(symbol: 'Rf', name: 'Rutherfordium',  atomicNumber: 104, atomicMass: 267.0,   family: ElementFamily.transition,      period: 7, group: 4),
  ChemicalElement(symbol: 'Db', name: 'Dubnium',        atomicNumber: 105, atomicMass: 268.0,   family: ElementFamily.transition,      period: 7, group: 5),
  ChemicalElement(symbol: 'Sg', name: 'Seaborgium',     atomicNumber: 106, atomicMass: 269.0,   family: ElementFamily.transition,      period: 7, group: 6),
  ChemicalElement(symbol: 'Bh', name: 'Bohrium',        atomicNumber: 107, atomicMass: 270.0,   family: ElementFamily.transition,      period: 7, group: 7),
  ChemicalElement(symbol: 'Hs', name: 'Hassium',        atomicNumber: 108, atomicMass: 277.0,   family: ElementFamily.transition,      period: 7, group: 8),
  ChemicalElement(symbol: 'Mt', name: 'Meitnerium',     atomicNumber: 109, atomicMass: 278.0,   family: ElementFamily.transition,      period: 7, group: 9),
  ChemicalElement(symbol: 'Ds', name: 'Darmstadtium',   atomicNumber: 110, atomicMass: 281.0,   family: ElementFamily.transition,      period: 7, group: 10),
  ChemicalElement(symbol: 'Rg', name: 'Roentgenium',    atomicNumber: 111, atomicMass: 282.0,   family: ElementFamily.transition,      period: 7, group: 11),
  ChemicalElement(symbol: 'Cn', name: 'Copernicium',    atomicNumber: 112, atomicMass: 285.0,   family: ElementFamily.transition,      period: 7, group: 12),
  ChemicalElement(symbol: 'Nh', name: 'Nihonium',       atomicNumber: 113, atomicMass: 286.0,   family: ElementFamily.postTransition,  period: 7, group: 13),
  ChemicalElement(symbol: 'Fl', name: 'Flerovium',      atomicNumber: 114, atomicMass: 289.0,   family: ElementFamily.postTransition,  period: 7, group: 14),
  ChemicalElement(symbol: 'Mc', name: 'Moscovium',      atomicNumber: 115, atomicMass: 290.0,   family: ElementFamily.postTransition,  period: 7, group: 15),
  ChemicalElement(symbol: 'Lv', name: 'Livermorium',    atomicNumber: 116, atomicMass: 293.0,   family: ElementFamily.postTransition,  period: 7, group: 16),
  ChemicalElement(symbol: 'Ts', name: 'Tennessine',     atomicNumber: 117, atomicMass: 294.0,   family: ElementFamily.halogen,         period: 7, group: 17),
  ChemicalElement(symbol: 'Og', name: 'Oganesson',      atomicNumber: 118, atomicMass: 294.0,   family: ElementFamily.nobleGas,        period: 7, group: 18),
];
