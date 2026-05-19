// ─────────────────────────────────────────────────────────
// Karachi Core Areas — Geographic Adjacency Map
// Covers: North Nazimabad, Gulshan-e-Iqbal, PECHS,
//         Nazimabad, Federal B Area, Gulistan-e-Johar,
//         DHA, Clifton
// ─────────────────────────────────────────────────────────

export const ADJACENT_BLOCKS = {

    // ── NORTH NAZIMABAD (Blocks A–R) ─────────────────────
    'North Nazimabad Block A': ['North Nazimabad Block B', 'North Nazimabad Block H'],
    'North Nazimabad Block B': ['North Nazimabad Block A', 'North Nazimabad Block C', 'North Nazimabad Block I'],
    'North Nazimabad Block C': ['North Nazimabad Block B', 'North Nazimabad Block D'],
    'North Nazimabad Block D': ['North Nazimabad Block C', 'North Nazimabad Block E', 'North Nazimabad Block J'],
    'North Nazimabad Block E': ['North Nazimabad Block D', 'North Nazimabad Block F'],
    'North Nazimabad Block F': ['North Nazimabad Block E', 'North Nazimabad Block G', 'North Nazimabad Block N'],
    'North Nazimabad Block G': ['North Nazimabad Block F', 'North Nazimabad Block H', 'North Nazimabad Block N'],
    'North Nazimabad Block H': ['North Nazimabad Block A', 'North Nazimabad Block G', 'North Nazimabad Block I'],
    'North Nazimabad Block I': ['North Nazimabad Block B', 'North Nazimabad Block H', 'North Nazimabad Block J'],
    'North Nazimabad Block J': ['North Nazimabad Block D', 'North Nazimabad Block I', 'North Nazimabad Block K'],
    'North Nazimabad Block K': ['North Nazimabad Block J', 'North Nazimabad Block L', 'North Nazimabad Block M', 'North Nazimabad Block N'],
    'North Nazimabad Block L': ['North Nazimabad Block K', 'North Nazimabad Block M'],
    'North Nazimabad Block M': ['North Nazimabad Block K', 'North Nazimabad Block L', 'North Nazimabad Block N'],
    'North Nazimabad Block N': ['North Nazimabad Block F', 'North Nazimabad Block G', 'North Nazimabad Block K', 'North Nazimabad Block M', 'North Nazimabad Block O'],
    'North Nazimabad Block O': ['North Nazimabad Block N', 'North Nazimabad Block P'],
    'North Nazimabad Block P': ['North Nazimabad Block O', 'North Nazimabad Block Q'],
    'North Nazimabad Block Q': ['North Nazimabad Block P', 'North Nazimabad Block R'],
    'North Nazimabad Block R': ['North Nazimabad Block Q'],

    // ── GULSHAN-E-IQBAL (Blocks 1–15, incl. 10A, 13A) ───
    'Gulshan-e-Iqbal Block 1':   ['Gulshan-e-Iqbal Block 2', 'Gulshan-e-Iqbal Block 3'],
    'Gulshan-e-Iqbal Block 2':   ['Gulshan-e-Iqbal Block 1', 'Gulshan-e-Iqbal Block 3', 'Gulshan-e-Iqbal Block 13'],
    'Gulshan-e-Iqbal Block 3':   ['Gulshan-e-Iqbal Block 1', 'Gulshan-e-Iqbal Block 2', 'Gulshan-e-Iqbal Block 4'],
    'Gulshan-e-Iqbal Block 4':   ['Gulshan-e-Iqbal Block 3', 'Gulshan-e-Iqbal Block 5'],
    'Gulshan-e-Iqbal Block 5':   ['Gulshan-e-Iqbal Block 4', 'Gulshan-e-Iqbal Block 6'],
    'Gulshan-e-Iqbal Block 6':   ['Gulshan-e-Iqbal Block 5', 'Gulshan-e-Iqbal Block 7'],
    'Gulshan-e-Iqbal Block 7':   ['Gulshan-e-Iqbal Block 6', 'Gulshan-e-Iqbal Block 8'],
    'Gulshan-e-Iqbal Block 8':   ['Gulshan-e-Iqbal Block 7', 'Gulshan-e-Iqbal Block 9'],
    'Gulshan-e-Iqbal Block 9':   ['Gulshan-e-Iqbal Block 8', 'Gulshan-e-Iqbal Block 10'],
    'Gulshan-e-Iqbal Block 10':  ['Gulshan-e-Iqbal Block 9', 'Gulshan-e-Iqbal Block 10A', 'Gulshan-e-Iqbal Block 11'],
    'Gulshan-e-Iqbal Block 10A': ['Gulshan-e-Iqbal Block 10', 'Gulshan-e-Iqbal Block 11', 'Gulshan-e-Iqbal Block 12', 'Gulshan-e-Iqbal Block 13'],
    'Gulshan-e-Iqbal Block 11':  ['Gulshan-e-Iqbal Block 10', 'Gulshan-e-Iqbal Block 10A', 'Gulshan-e-Iqbal Block 12'],
    'Gulshan-e-Iqbal Block 12':  ['Gulshan-e-Iqbal Block 10A', 'Gulshan-e-Iqbal Block 11', 'Gulshan-e-Iqbal Block 13'],
    'Gulshan-e-Iqbal Block 13':  ['Gulshan-e-Iqbal Block 2', 'Gulshan-e-Iqbal Block 10A', 'Gulshan-e-Iqbal Block 12', 'Gulshan-e-Iqbal Block 13A', 'Gulshan-e-Iqbal Block 14'],
    'Gulshan-e-Iqbal Block 13A': ['Gulshan-e-Iqbal Block 13', 'Gulshan-e-Iqbal Block 14'],
    'Gulshan-e-Iqbal Block 14':  ['Gulshan-e-Iqbal Block 13', 'Gulshan-e-Iqbal Block 13A', 'Gulshan-e-Iqbal Block 15'],
    'Gulshan-e-Iqbal Block 15':  ['Gulshan-e-Iqbal Block 14'],

    // ── PECHS (Blocks 1–8, incl. 7A) ─────────────────────
    'PECHS Block 1':  ['PECHS Block 2', 'PECHS Block 3'],
    'PECHS Block 2':  ['PECHS Block 1', 'PECHS Block 3', 'PECHS Block 6'],
    'PECHS Block 3':  ['PECHS Block 1', 'PECHS Block 2', 'PECHS Block 4'],
    'PECHS Block 4':  ['PECHS Block 3', 'PECHS Block 5'],
    'PECHS Block 5':  ['PECHS Block 4', 'PECHS Block 7A'],
    'PECHS Block 6':  ['PECHS Block 2', 'PECHS Block 7', 'PECHS Block 7A'],
    'PECHS Block 7':  ['PECHS Block 6', 'PECHS Block 7A'],
    'PECHS Block 7A': ['PECHS Block 5', 'PECHS Block 6', 'PECHS Block 7'],

    // ── NAZIMABAD (Blocks 1–6) ────────────────────────────
    'Nazimabad Block 1': ['Nazimabad Block 2'],
    'Nazimabad Block 2': ['Nazimabad Block 1', 'Nazimabad Block 3'],
    'Nazimabad Block 3': ['Nazimabad Block 2', 'Nazimabad Block 4'],
    'Nazimabad Block 4': ['Nazimabad Block 3', 'Nazimabad Block 5'],
    'Nazimabad Block 5': ['Nazimabad Block 4', 'Nazimabad Block 6'],
    'Nazimabad Block 6': ['Nazimabad Block 5'],

    // ── FEDERAL B AREA (Blocks 1–20) ──────────────────────
    'Federal B Area Block 1':  ['Federal B Area Block 2',  'Federal B Area Block 6'],
    'Federal B Area Block 2':  ['Federal B Area Block 1',  'Federal B Area Block 3',  'Federal B Area Block 7'],
    'Federal B Area Block 3':  ['Federal B Area Block 2',  'Federal B Area Block 4',  'Federal B Area Block 8'],
    'Federal B Area Block 4':  ['Federal B Area Block 3',  'Federal B Area Block 5',  'Federal B Area Block 9'],
    'Federal B Area Block 5':  ['Federal B Area Block 4',  'Federal B Area Block 10'],
    'Federal B Area Block 6':  ['Federal B Area Block 1',  'Federal B Area Block 7',  'Federal B Area Block 11'],
    'Federal B Area Block 7':  ['Federal B Area Block 2',  'Federal B Area Block 6',  'Federal B Area Block 8',  'Federal B Area Block 12'],
    'Federal B Area Block 8':  ['Federal B Area Block 3',  'Federal B Area Block 7',  'Federal B Area Block 9',  'Federal B Area Block 13'],
    'Federal B Area Block 9':  ['Federal B Area Block 4',  'Federal B Area Block 8',  'Federal B Area Block 10', 'Federal B Area Block 14'],
    'Federal B Area Block 10': ['Federal B Area Block 5',  'Federal B Area Block 9',  'Federal B Area Block 15'],
    'Federal B Area Block 11': ['Federal B Area Block 6',  'Federal B Area Block 12', 'Federal B Area Block 16'],
    'Federal B Area Block 12': ['Federal B Area Block 7',  'Federal B Area Block 11', 'Federal B Area Block 13', 'Federal B Area Block 17'],
    'Federal B Area Block 13': ['Federal B Area Block 8',  'Federal B Area Block 12', 'Federal B Area Block 14', 'Federal B Area Block 18'],
    'Federal B Area Block 14': ['Federal B Area Block 9',  'Federal B Area Block 13', 'Federal B Area Block 15', 'Federal B Area Block 19'],
    'Federal B Area Block 15': ['Federal B Area Block 10', 'Federal B Area Block 14', 'Federal B Area Block 20'],
    'Federal B Area Block 16': ['Federal B Area Block 11', 'Federal B Area Block 17'],
    'Federal B Area Block 17': ['Federal B Area Block 12', 'Federal B Area Block 16', 'Federal B Area Block 18'],
    'Federal B Area Block 18': ['Federal B Area Block 13', 'Federal B Area Block 17', 'Federal B Area Block 19'],
    'Federal B Area Block 19': ['Federal B Area Block 14', 'Federal B Area Block 18', 'Federal B Area Block 20'],
    'Federal B Area Block 20': ['Federal B Area Block 15', 'Federal B Area Block 19'],

    // ── GULISTAN-E-JOHAR (Blocks 1–18) ───────────────────
    'Gulistan-e-Johar Block 1':  ['Gulistan-e-Johar Block 2',  'Gulistan-e-Johar Block 13'],
    'Gulistan-e-Johar Block 2':  ['Gulistan-e-Johar Block 1',  'Gulistan-e-Johar Block 3'],
    'Gulistan-e-Johar Block 3':  ['Gulistan-e-Johar Block 2',  'Gulistan-e-Johar Block 4',  'Gulistan-e-Johar Block 14'],
    'Gulistan-e-Johar Block 4':  ['Gulistan-e-Johar Block 3',  'Gulistan-e-Johar Block 5'],
    'Gulistan-e-Johar Block 5':  ['Gulistan-e-Johar Block 4',  'Gulistan-e-Johar Block 6',  'Gulistan-e-Johar Block 15'],
    'Gulistan-e-Johar Block 6':  ['Gulistan-e-Johar Block 5',  'Gulistan-e-Johar Block 7'],
    'Gulistan-e-Johar Block 7':  ['Gulistan-e-Johar Block 6',  'Gulistan-e-Johar Block 8',  'Gulistan-e-Johar Block 16'],
    'Gulistan-e-Johar Block 8':  ['Gulistan-e-Johar Block 7',  'Gulistan-e-Johar Block 9'],
    'Gulistan-e-Johar Block 9':  ['Gulistan-e-Johar Block 8',  'Gulistan-e-Johar Block 10', 'Gulistan-e-Johar Block 17'],
    'Gulistan-e-Johar Block 10': ['Gulistan-e-Johar Block 9',  'Gulistan-e-Johar Block 11'],
    'Gulistan-e-Johar Block 11': ['Gulistan-e-Johar Block 10', 'Gulistan-e-Johar Block 12', 'Gulistan-e-Johar Block 18'],
    'Gulistan-e-Johar Block 12': ['Gulistan-e-Johar Block 11'],
    'Gulistan-e-Johar Block 13': ['Gulistan-e-Johar Block 1',  'Gulistan-e-Johar Block 14'],
    'Gulistan-e-Johar Block 14': ['Gulistan-e-Johar Block 3',  'Gulistan-e-Johar Block 13', 'Gulistan-e-Johar Block 15'],
    'Gulistan-e-Johar Block 15': ['Gulistan-e-Johar Block 5',  'Gulistan-e-Johar Block 14', 'Gulistan-e-Johar Block 16'],
    'Gulistan-e-Johar Block 16': ['Gulistan-e-Johar Block 7',  'Gulistan-e-Johar Block 15', 'Gulistan-e-Johar Block 17'],
    'Gulistan-e-Johar Block 17': ['Gulistan-e-Johar Block 9',  'Gulistan-e-Johar Block 16', 'Gulistan-e-Johar Block 18'],
    'Gulistan-e-Johar Block 18': ['Gulistan-e-Johar Block 11', 'Gulistan-e-Johar Block 17'],

    // ── DHA (Phases 1–8) ──────────────────────────────────
    'DHA Phase 1': ['DHA Phase 2'],
    'DHA Phase 2': ['DHA Phase 1', 'DHA Phase 3'],
    'DHA Phase 3': ['DHA Phase 2', 'DHA Phase 4'],
    'DHA Phase 4': ['DHA Phase 3', 'DHA Phase 5'],
    'DHA Phase 5': ['DHA Phase 4', 'DHA Phase 6'],
    'DHA Phase 6': ['DHA Phase 5', 'DHA Phase 7'],
    'DHA Phase 7': ['DHA Phase 6', 'DHA Phase 8'],
    'DHA Phase 8': ['DHA Phase 7'],

    // ── CLIFTON (Blocks 1–9) ──────────────────────────────
    'Clifton Block 1': ['Clifton Block 2'],
    'Clifton Block 2': ['Clifton Block 1', 'Clifton Block 3'],
    'Clifton Block 3': ['Clifton Block 2', 'Clifton Block 4'],
    'Clifton Block 4': ['Clifton Block 3', 'Clifton Block 5'],
    'Clifton Block 5': ['Clifton Block 4', 'Clifton Block 6'],
    'Clifton Block 6': ['Clifton Block 5', 'Clifton Block 7'],
    'Clifton Block 7': ['Clifton Block 6', 'Clifton Block 8'],
    'Clifton Block 8': ['Clifton Block 7', 'Clifton Block 9'],
    'Clifton Block 9': ['Clifton Block 8'],
};

export function getAdjacentBlocks(blockId) {
    return ADJACENT_BLOCKS[blockId] || [];
}