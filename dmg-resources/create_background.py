#!/usr/bin/env python3
"""
Create a DMG background image with drag-to-Applications arrow design.
"""

from PIL import Image, ImageDraw, ImageFont
import os

# DMG window size (standard size for nice layout)
WIDTH = 660
HEIGHT = 400

# Colors - Light background for better contrast with macOS Finder icons
BG_COLOR = (245, 245, 247)  # Light gray background
TEXT_COLOR = (30, 30, 30)  # Dark text
ARROW_COLOR = (19, 113, 91)  # DodoTidy green #13715B
SECONDARY_TEXT = (100, 100, 100)  # Darker gray for secondary text

def create_background():
    # Create image
    img = Image.new('RGB', (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Try to load a nice font, fall back to default
    try:
        # macOS system fonts
        title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
        subtitle_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    except:
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()

    # Draw "Drag to Applications" text at top
    title_text = "Drag to Applications"
    bbox = draw.textbbox((0, 0), title_text, font=title_font)
    text_width = bbox[2] - bbox[0]
    draw.text(((WIDTH - text_width) // 2, 30), title_text, fill=TEXT_COLOR, font=title_font)

    # Draw arrow in the middle (pointing right)
    # Arrow position: between where app icon will be (left) and Applications folder (right)
    arrow_y = HEIGHT // 2 + 20
    arrow_start_x = WIDTH // 2 - 60
    arrow_end_x = WIDTH // 2 + 60

    # Draw arrow line
    arrow_thickness = 4
    for i in range(-arrow_thickness//2, arrow_thickness//2 + 1):
        draw.line([(arrow_start_x, arrow_y + i), (arrow_end_x - 15, arrow_y + i)], fill=ARROW_COLOR, width=1)

    # Draw arrow head
    arrow_head_size = 20
    draw.polygon([
        (arrow_end_x, arrow_y),
        (arrow_end_x - arrow_head_size, arrow_y - arrow_head_size//2 - 3),
        (arrow_end_x - arrow_head_size, arrow_y + arrow_head_size//2 + 3)
    ], fill=ARROW_COLOR)

    # Draw subtle hint text at bottom
    hint_text = "Then run: xattr -cr /Applications/DodoTidy.app"
    bbox = draw.textbbox((0, 0), hint_text, font=subtitle_font)
    text_width = bbox[2] - bbox[0]
    draw.text(((WIDTH - text_width) // 2, HEIGHT - 50), hint_text, fill=SECONDARY_TEXT, font=subtitle_font)

    # Save
    output_path = os.path.join(os.path.dirname(__file__), 'background.png')
    img.save(output_path, 'PNG')
    print(f"Background saved to: {output_path}")

    # Also save a @2x version for Retina
    img_2x = img.resize((WIDTH * 2, HEIGHT * 2), Image.Resampling.LANCZOS)
    output_path_2x = os.path.join(os.path.dirname(__file__), 'background@2x.png')
    img_2x.save(output_path_2x, 'PNG')
    print(f"Retina background saved to: {output_path_2x}")

if __name__ == '__main__':
    create_background()
