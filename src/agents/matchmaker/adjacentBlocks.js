export const ADJACENT_BLOCKS = {
    'North Nazimabad Block N': ['North Nazimabad Block M', 'North Nazimabad Block K', 'North Nazimabad Block F'],
    'North Nazimabad Block M': ['North Nazimabad Block N', 'North Nazimabad Block L', 'North Nazimabad Block K'],
    'North Nazimabad Block F': ['North Nazimabad Block N', 'North Nazimabad Block E', 'North Nazimabad Block G'],
    'North Nazimabad Block K': ['North Nazimabad Block N', 'North Nazimabad Block M'],
    'Gulshan-e-Iqbal Block 13': ['Gulshan-e-Iqbal Block 14', 'Gulshan-e-Iqbal Block 10A', 'Gulshan-e-Iqbal Block 15'],
    'Gulshan-e-Iqbal Block 15': ['Gulshan-e-Iqbal Block 14', 'Gulshan-e-Iqbal Block 13'],
    'PECHS Block 6': ['PECHS Block 2', 'PECHS Block 7'],
    'PECHS Block 2': ['PECHS Block 6', 'PECHS Block 3'],
};

export function getAdjacentBlocks(blockId) {
    return ADJACENT_BLOCKS[blockId] || [];
}