from PIL import Image

im = Image.open(r"C:\Users\JAYESH PATIL\.gemini\antigravity-ide\brain\f7bfb395-c613-4d57-b82e-0bef53afcadf\live_device_screen.png")
w, h = im.size
print(f"Size: {w}x{h}")

# The button has text color around R: 96, G: 55, B: 9 (0x603709) or button background around (236, 231, 225)
# Let's search in region x: 250..650, y: 1400..2100
matches = []
for y in range(1400, 2200, 2):
    for x in range(300, 700, 2):
        r, g, b, *a = im.getpixel((x, y))
        # Check text color (dark brown)
        if 80 <= r <= 110 and 45 <= g <= 70 and 0 <= b <= 25:
            matches.append((x, y))

if matches:
    xs = [m[0] for m in matches]
    ys = [m[1] for m in matches]
    print(f"Found {len(matches)} pixels matching text color:")
    print(f"X range: {min(xs)} - {max(xs)}, Y range: {min(ys)} - {max(ys)}")
    print(f"Center: ({(min(xs)+max(xs))//2}, {(min(ys)+max(ys))//2})")
else:
    print("No exact text color matches in this range, scanning broader...")
    for y in range(1000, 2500, 10):
        for x in range(200, 700, 10):
            r, g, b, *a = im.getpixel((x, y))
            if 80 <= r <= 110 and 45 <= g <= 70 and 0 <= b <= 25:
                matches.append((x, y))
    if matches:
        print(f"Broader matches found: {len(matches)}, sample: {matches[:5]}")
