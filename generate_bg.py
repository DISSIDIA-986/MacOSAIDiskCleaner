import colorsys
from PIL import Image, ImageDraw

def create_gradient_image(width, height, start_color, end_color, filename):
    base = Image.new('RGB', (width, height), start_color)
    top = Image.new('RGB', (width, height), end_color)
    mask = Image.new('L', (width, height))
    mask_data = []
    for y in range(height):
        for x in range(width):
            mask_data.append(int(255 * (y / height)))
    mask.putdata(mask_data)
    base.paste(top, (0, 0), mask)
    base.save(filename)

# Create a 600x400 background (standard DMG size)
# Light blue to white gradient
create_gradient_image(600, 400, (230, 240, 255), (255, 255, 255), "dmg_background.png")
print("Background image created: dmg_background.png")
