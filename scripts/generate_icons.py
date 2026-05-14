# brew install python pillow inkscape
#
# Optional: create a virtual environment
#   python3 -m venv .venv && source .venv/bin/activate && pip install pillow
#
# Usage:
#   python3 generate_icons.py <input_image.(png|jpg|svg)>

from PIL import Image
import os
import sys
import subprocess
import tempfile
import json

# Define the required icon sizes and their Contents.json mapping
icon_sizes = {
    "iOS_1024pt": (1024, 1024),
    "macOS_16pt_1x": (16, 16),
    "macOS_16pt_2x": (32, 32),
    "macOS_32pt_1x": (32, 32),
    "macOS_32pt_2x": (64, 64),
    "macOS_128pt_1x": (128, 128),
    "macOS_128pt_2x": (256, 256),
    "macOS_256pt_1x": (256, 256),
    "macOS_256pt_2x": (512, 512),
    "macOS_512pt_1x": (512, 512),
    "macOS_512pt_2x": (1024, 1024),
    "App_Store_2x": (1024, 1024),
}

def create_contents_json(main_image_filename):
    """Create the Contents.json file for the .appiconset with proper iOS and macOS entries."""
    contents = {
        "images": [
            # Main iOS icon (1024x1024)
            {
                "filename": main_image_filename,
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            },
            # Dark appearance variant (placeholder)
            {
                "appearances": [
                    {
                        "appearance": "luminosity",
                        "value": "dark"
                    }
                ],
                "filename": "iOS_1024pt.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            },
            # Tinted appearance variant (placeholder)
            {
                "appearances": [
                    {
                        "appearance": "luminosity",
                        "value": "tinted"
                    }
                ],
                "filename": "iOS_1024pt_tinted.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            },
            # macOS icons
            {
                "filename": "macOS_16pt_1x.png",
                "idiom": "mac",
                "scale": "1x",
                "size": "16x16"
            },
            {
                "filename": "macOS_16pt_2x.png",
                "idiom": "mac",
                "scale": "2x",
                "size": "16x16"
            },
            {
                "filename": "macOS_32pt_1x.png",
                "idiom": "mac",
                "scale": "1x",
                "size": "32x32"
            },
            {
                "filename": "macOS_32pt_2x.png",
                "idiom": "mac",
                "scale": "2x",
                "size": "32x32"
            },
            {
                "filename": "macOS_128pt_1x.png",
                "idiom": "mac",
                "scale": "1x",
                "size": "128x128"
            },
            {
                "filename": "macOS_128pt_2x.png",
                "idiom": "mac",
                "scale": "2x",
                "size": "128x128"
            },
            {
                "filename": "macOS_256pt_1x.png",
                "idiom": "mac",
                "scale": "1x",
                "size": "256x256"
            },
            {
                "filename": "macOS_256pt_2x.png",
                "idiom": "mac",
                "scale": "2x",
                "size": "256x256"
            },
            {
                "filename": "macOS_512pt_1x.png",
                "idiom": "mac",
                "scale": "1x",
                "size": "512x512"
            },
            {
                "filename": "macOS_512pt_2x.png",
                "idiom": "mac",
                "scale": "2x",
                "size": "512x512"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    return contents

def convert_svg_to_image(svg_path, size):
    """Convert SVG to RGB image with specified size using Inkscape."""
    with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp_file:
        output_path = tmp_file.name
        
    # Scale up for better quality
    scale_factor = 2
    scaled_size = (size[0] * scale_factor, size[1] * scale_factor)
    
    try:
        subprocess.run([
            'inkscape',
            '--export-type=png',
            '--export-filename=' + output_path,
            f'--export-width={scaled_size[0]}',
            f'--export-height={scaled_size[1]}',
            # '--export-background-opacity=1',
            # '--export-area-drawing',  # Export the area containing the drawing
            svg_path
        ], check=True, capture_output=True, text=True)
        
        # Open the generated PNG and resize it down if needed
        img = Image.open(output_path)
        if scaled_size != size:
            img = img.resize(size, Image.LANCZOS)
        
        # Convert to RGB for JPEG compatibility
        if img.mode in ('RGBA', 'LA'):
            # Create a white background for images with transparency
            background = Image.new('RGB', img.size, (255, 255, 255))
            if img.mode == 'RGBA':
                background.paste(img, mask=img.split()[-1])  # Use alpha channel as mask
            else:
                background.paste(img, mask=img.split()[-1])  # Use transparency channel as mask
            img = background
        elif img.mode != 'RGB':
            img = img.convert('RGB')
            
        return img
    except subprocess.CalledProcessError as e:
        print(f"Inkscape error: {e.stderr}")
        raise
    finally:
        # Clean up the temporary file
        if os.path.exists(output_path):
            os.unlink(output_path)

def generate_app_icons(input_image_path, output_folder):
    """Generate app icons from the input image (SVG, PNG, or JPG) as PNG files."""
    
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
    
    is_svg = input_image_path.lower().endswith('.svg')
    
    # Get the original image filename for the main iOS icon
    original_filename = os.path.basename(input_image_path)
    original_name, original_ext = os.path.splitext(original_filename)
    main_image_filename = f"{original_name}.png"
    
    for name, size in icon_sizes.items():
        try:
            if is_svg:
                # For SVG, use Inkscape for conversion
                img = convert_svg_to_image(input_image_path, size)
                # Use original filename for iOS_1024pt, otherwise use generated name
                if name == "iOS_1024pt":
                    output_path = os.path.join(output_folder, main_image_filename)
                else:
                    output_path = os.path.join(output_folder, f"{name}.png")
                img.save(output_path, format="PNG")
            else:
                # For PNG and JPG, use PIL for resizing
                with Image.open(input_image_path) as img:
                    # Keep original image mode for PNG output (preserves transparency)
                    resized_img = img.resize(size, Image.LANCZOS)
                    # Use original filename for iOS_1024pt, otherwise use generated name
                    if name == "iOS_1024pt":
                        output_path = os.path.join(output_folder, main_image_filename)
                    else:
                        output_path = os.path.join(output_folder, f"{name}.png")
                    resized_img.save(output_path, format="PNG")
            
            print(f"Saved: {output_path}")
        except Exception as e:
            print(f"Error processing {name}: {str(e)}")
    
    # Generate Contents.json file
    contents_json = create_contents_json(main_image_filename)
    contents_path = os.path.join(output_folder, "Contents.json")
    with open(contents_path, 'w') as f:
        json.dump(contents_json, f, indent=2)
    print(f"Created: {contents_path}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 generate_icons.py <input_image.(png|jpg|svg)>")
        sys.exit(1)

    input_image_path = sys.argv[1]
    if not input_image_path.lower().endswith(('.png', '.jpg', '.jpeg', '.svg')):
        print("Error: Input file must be PNG, JPG, or SVG format")
        sys.exit(1)

    # Check if the input file is within an .appiconset directory
    input_dir = os.path.dirname(os.path.abspath(input_image_path))
    if input_dir.endswith('.appiconset'):
        # Use the .appiconset directory as output folder
        output_folder = input_dir
        print(f"Detected .appiconset directory: {output_folder}")
    else:
        # Use default AppIcons folder
        output_folder = "AppIcons"
        print(f"Using default output folder: {output_folder}")

    generate_app_icons(input_image_path, output_folder)