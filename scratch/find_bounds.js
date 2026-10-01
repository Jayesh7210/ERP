const fs = require('fs');
const xml = fs.readFileSync('scratch/window_dump.xml', 'utf8');
const regex = /(text|content-desc)="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/g;
let m;
while ((m = regex.exec(xml)) !== null) {
  if (m[2].trim().length > 0) {
    const cx = (parseInt(m[3]) + parseInt(m[5])) / 2;
    const cy = (parseInt(m[4]) + parseInt(m[6])) / 2;
    console.log(`${m[1]}: "${m[2]}" -> Center: (${cx}, ${cy})`);
  }
}
