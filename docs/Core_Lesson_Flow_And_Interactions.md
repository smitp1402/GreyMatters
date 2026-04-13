# NeuroLearn — Lesson Content & Interaction Formats

## Subjects & Topics

| Subject | Topic | Sections | Est. Time |
|---------|-------|----------|-----------|
| Chemistry | Chemical Bonding | Ionic vs covalent bonds + static bond diagram | 8-10 min |
| Chemistry | Periodic Table | History, Element Groups, Trends, Reading the Table | 10 min |
| Biology | Cell Structure | Organelles + labelled cell diagram | 8-10 min |
| Biology | DNA Replication | Base pairs, replication, double helix | 8-10 min |

---

## Lesson Format

- White background, Times New Roman, dense text, static diagrams
- Intentionally low-stimulation — mimics real textbook/lecture material
- Focus HUD at bottom: live focus gauge + theta/alpha/beta/gamma bars
- Content pauses on drift, resumes from exact position after recovery

---

## 7 Intervention Formats

| # | Format | Input | Duration | Drift Level | What Student Does |
|---|--------|-------|----------|-------------|-------------------|
| 1 | Flashcard Deck | Swipe/Tap | 30-60s | Mild (4-8s) | Swipe through 5 Q&A cards per topic |
| 2 | Video Clip | Watch + 1 MCQ | 90-120s | Moderate (8-20s) | Watch 90s clip, answer 1 question |
| 3 | Simulation | Drag & Drop | 60-90s | Moderate (8-20s) | Drag elements to correct positions |
| 4 | Voice Challenge | Mic / Type | 30-45s | Severe (20+s) | TTS asks, student speaks answer |
| 5 | Hand Gesture | Camera | 20-40s | Lost | Hold up fingers / point on screen |
| 6 | Curiosity Bomb | Passive | 3s | Any | Full-screen surprising fact, auto-dismiss |
| 7 | Draw-It | Stylus/Finger | ~60s | Any | Draw concept from memory (deferred) |

---

## Intervention Content Per Topic

### Chemistry — Chemical Bonding

| Format | Content |
|--------|---------|
| Flashcard | Classify H₂O, NaCl, CO₂ — ionic or covalent? (5 cards) |
| Video | CrashCourse: electron sharing in covalent bonds (90s) → "What is shared in a covalent bond?" |
| Simulation | Drag electrons between atoms to form H₂O bonds |
| Voice | "What type of bond forms when H and O share electrons?" → covalent |
| Gesture | Hold up fingers = bond count (Carbon=4, Hydrogen=1) |
| Curiosity Bomb | "Diamond and pencil graphite are both pure carbon — same covalent bonds, different arrangement." |

### Chemistry — Periodic Table

| Format | Content |
|--------|---------|
| Flashcard | 118 elements, Mendeleev, atomic number, noble gas vs halogen, electronegativity (5 cards) |
| Video | CrashCourse: periodic table intro (90s) → "What do elements in the same group share?" |
| Simulation | Drag Na, Cl, Fe, He, Ca to correct positions on periodic table grid |
| Voice | "What type of element is Fluorine?" / "Name element with atomic number 79" / "What trend increases left to right?" / "Center of chlorophyll?" |
| Gesture | Valence electrons: Na=1 finger, C=4 fingers, Cl=7 fingers |
| Curiosity Bomb | "99% of your body is just 6 elements. Line up every atom and it stretches 2 light-years." |

### Biology — Cell Structure

| Format | Content |
|--------|---------|
| Flashcard | Organelle → function: mitochondria, nucleus, ribosome, membrane, ER (5 cards) |
| Video | Khan Academy: how organelles work together (90s) → "Which organelle produces energy?" |
| Simulation | Drag organelles into correct positions in blank cell diagram |
| Voice | "Which organelle produces energy?" / "What surrounds the cell?" |
| Gesture | Point to correct organelle on screen diagram |
| Curiosity Bomb | "37.2 trillion cells in your body. If each were a marble, you'd fill 1,000 Olympic pools." |

### Biology — DNA Replication

| Format | Content |
|--------|---------|
| Flashcard | DNA stands for, 4 bases, pairing rule (A-T, G-C), double helix, helicase (5 cards) |
| Video | CrashCourse: DNA replication (90s) → "What enzyme unzips the double helix?" |
| Simulation | Drag complementary bases to complete strand: A-T-G-C-A-T → T-A-C-G-T-A |
| Voice | "What pairs with Adenine?" → thymine / "Shape of DNA?" → double helix |
| Gesture | Hold up fingers: 4 bases, 2 strands |
| Curiosity Bomb | "DNA in one cell = 2 meters. All your DNA? Sun to Pluto and back, 17 times." |

---

## RL Agent — Format Selection

| Sessions | Agent | How It Picks |
|----------|-------|-------------|
| 1-5 | Rule-based | Fixed: mild→flashcard, moderate→video/simulation, severe→voice, lost→gesture |
| 6-30 | Contextual bandit | Learns per-student: picks format with highest recovery rate, 10% exploration |
| 30+ | DQN (deferred) | Neural net on-device, generalizes across topics |

**Reward:** +1 if student's EEG returns to focused within 60s after intervention, -1 if not.

**Cascade:** If first format fails → RL picks next best → repeat → all exhausted → "Take a 2-minute break."

---

## TODO — Design Interaction Content

### Periodic Table

- [ ] Flashcard: Write 5 Q&A cards (question, answer, explanation for each)
- [ ] Video: Find exact YouTube URL for 90s clip, write 1 MCQ with 3-4 options
- [ ] Simulation: Define grid layout, which cells are drop targets, snap positions for Na/Cl/Fe/He/Ca
- [ ] Voice: Finalize 4 questions with all accepted answer variations
- [ ] Gesture: Define finger-count answers, decide how to handle numbers >10 (e.g. Group 18)
- [ ] Curiosity Bomb: Finalize fact text and display style
- [ ] Lesson sections: Write/review all 4 sections text content and key terms
- [ ] Confirmation MCQs: Write 1 MCQ per section (shown after recovery)
- [ ] Recap sentences: Write 1 recap per section ("You were learning about...")
- [ ] Real-world connection card: Finalize text for section completion reward

### Chemical Bonding

- [ ] Flashcard: Write 5 Q&A cards (question, answer, explanation for each)
- [ ] Video: Find exact YouTube URL for 90s clip, write 1 MCQ with 3-4 options
- [ ] Simulation: Define atom layout, electron drag positions, what "correct bond" looks like for H₂O
- [ ] Voice: Finalize questions with all accepted answer variations
- [ ] Gesture: Define finger-count questions, map bond counts to elements
- [ ] Curiosity Bomb: Finalize fact text
- [ ] Lesson sections: Write 3 sections (ionic bonds, covalent bonds, comparing both) + key terms
- [ ] Confirmation MCQs: Write 1 MCQ per section
- [ ] Recap sentences: Write 1 recap per section
- [ ] Real-world connection card: Finalize text
- [ ] Create `assets/curriculum/chemical_bonding.json` (periodic_table.json exists, this one doesn't)

---

## Potential Ideas — Future Interactions

### Computer Vision Based Interaction

- **Element Spotter** — Student holds up a real object (salt, water bottle, coin) to camera. CV model identifies the object and student must name the elements in it. Salt → Na + Cl. Water → H + O. Coin → Cu + Zn.
- **Whiteboard Solve** — Student writes a chemical formula on paper, holds it to camera. OCR reads it, app checks if it's correct for the given prompt (e.g. "Write the formula for calcium chloride" → CaCl₂).
- **Gesture Periodic Table** — Camera tracks hand position over a printed/on-screen periodic table. App calls out random elements, student points to them. Measures speed and accuracy.
- **Bond Builder with Hands** — Student uses two hands to represent atoms. Move hands close = bond forms. Move apart = bond breaks. Number of fingers up = electrons shared. Camera tracks both hands via MediaPipe.
- **Flash Element ID** — App shows element symbol for 2 seconds, hides it. Student must hold up fingers for the atomic number. Camera verifies. Speed rounds get faster.

### Music / Song Based Interaction — Memorize Elements

- **Element Song Playback** — Play "The Element Song" by Tom Lehrer (or AsapSCIENCE periodic table song). Student listens, then app quizzes: "What element comes after Argon in the song?" Forces sequential memory.
- **Fill-in-the-Lyric** — Song plays with gaps. Student types or speaks the missing element. "There's hydrogen and helium, then ___ and ___..." → lithium, beryllium.
- **Rhythm Tap Game** — Elements flash on screen to a beat. Student taps in rhythm when the correct group appears (e.g. tap only for noble gases). Trains classification + timing.
- **Sing-Along Karaoke** — Lyrics on screen, element names highlighted. After sing-along, random elements blanked out — student fills from memory. Repetition through music = stronger recall.
- **Create Your Mnemonic** — App gives first 10 elements. Student records a voice jingle. App plays it back before each quiz. Personal mnemonics stick better than generic ones.

### References

- https://www.instagram.com/reel/DW-7-HekbQz/?igsh=MWJ0ODUxMzdmem96aQ==
- https://www.instagram.com/reel/DW6ovrZEeDk/?igsh=aWw4ejg1OW12cDFy
- https://www.instagram.com/reel/DWzB1K_iZIg/?igsh=a2M4ZGVkYnI3ZGho
