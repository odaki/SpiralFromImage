// SpiralfromImage
// Copyright Jan Krummrey 2016
//
// Forked version
// (C) 2021 Michiyasu Odaki
//
// Idea taken from Norwegian Creations Drawbot
// http://www.norwegiancreations.com/2012/04/drawing-machine-part-2/
//
// The sketch takes an image and turns it into a modulated spiral.
// Dark parts of the image have larger amplitudes.
// The result is being writen to a PDF for refinement in Illustrator/Inkscape
//
// Version
// 1.0 Buggy PDF export
// 1.1 added SVG export and flag to swith off PDF export
// 1.2 removed PDF export
//     added and reworked CP5 gui (taken from max_bol's fork)
//     fixed wrong SVG header
//
// Forked version
// 1.3 support live preview
//     support PDF export
//     choose centerpoint with mouse or numeric box
// 1.4 support transparency
//     remove mask color function
//     check to see if the image format is supported on open
//     automatically calculate ampScale
// 1.5 rename clear display button to view original
//     fixed the spiral data could be out of the display size range
//     support drawing in white on a black canvas
//     draw a guide frame around the original image
//     draw a checkered pattern as a canvas to make the transparent image easier to see
// 1.6 added color mode
//
// SpiralfromImage is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with SpiralfromImage.  If not, see <http://www.gnu.org/licenses/>.
//
// jan@krummrey.de
// http://jan.krummrey.de

import java.io.File;                       // Required for file path operations

import processing.svg.*;
import processing.pdf.*;

import controlP5.*;                        // CP5 for gui

ControlP5 cp5;

Textarea feedbackText;

static final int INTERNAL_IMAGE_SIZE = 1200;
static final int DISPLAY_IMAGE_SIZE = 600;
static final float SCALE_RATIO = float(DISPLAY_IMAGE_SIZE) / float(INTERNAL_IMAGE_SIZE);

String sourceImgPath = "";                 // Source image absolute location
boolean isLoaded = false;                  // Whether the source image has been loaded or not
PImage sourceImg;                          // Source image for conversion
PImage displayImg;                         // Image to use as display

float distance = 5;                        // Distance between rings
float density = 36;                        // Density

int centerPointX = INTERNAL_IMAGE_SIZE / 2;    // Center point of spiral
int centerPointY = INTERNAL_IMAGE_SIZE / 2;    // Center point of spiral
float endRadius = INTERNAL_IMAGE_SIZE / 2;     // Largest value the spiral needs to cover the image

PShape outputSpiral = null;                // Spriral shape to draw

PShape outputSpiralC = null;
PShape outputSpiralM = null;
PShape outputSpiralY = null;

static final int PENCOLORMODE_BLACK = 0;
static final int PENCOLORMODE_WHITE = 1;
static final int PENCOLORMODE_COLORS = 2;
int penColorMode = PENCOLORMODE_BLACK;

boolean useCircleShape = false;
boolean usePreview = true;

color canvasColor = 255;
color guideFrameColor = color(0x00, 0x33, 0x68);

// internal state variables
boolean needToUpdatePreview = false;
boolean needToDrawOriginalImage = false;

static final int CANVAS_ORIGIN_X = 187;
static final int CANVAS_ORIGIN_Y = 85;
final int guiBorder = 12;

int canvasWidth = DISPLAY_IMAGE_SIZE;
int canvasHeight = DISPLAY_IMAGE_SIZE;

void settings() {
  size(174 + DISPLAY_IMAGE_SIZE + 25 * 2, 75 + DISPLAY_IMAGE_SIZE + 25 * 2);
}

void setup() {
  drawBackground();
  outputSpiral = createShape(GROUP);
  setupGUI();
}

void draw() {
  if (needToDrawOriginalImage) {
    needToDrawOriginalImage = false;
    clearCanvas();
    drawOriginalImage();
    drawFrame();
  }
  if (needToUpdatePreview) {
    needToUpdatePreview = false;
    updateOutputSpiral();
    clearCanvas();
    drawSpiral();
    drawFrame();
  }
}

void setupGUI() {
  cp5 = new ControlP5(this);

  final int x0 = 37;  // parts align x
  final int y0 = 37;  // parts align y
  final int h0 = 19;  // parts height
  final int w0 = 100; // parts width
  final int s0 = 6;   // parts spacing
  final int t0 = 12;  // label height

  int xx = x0;
  int yy = y0;

  // Create a new button with name 'openFileButton'
  cp5.addButton("openFileButton")
    .setLabel("Open File")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);

  yy += t0; // some space for grouping

  // Create a new button with name 'generateSpiralButton'
  cp5.addButton("generateSpiralButton")
    .setLabel("Generate Spiral")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);

  // Create a new button with name 'viewOriginalButton'
  cp5.addButton("viewOriginalButton")
    .setLabel("View Original")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);

  yy += t0; // some space for grouping

  // Create a radio button to select color mode: default is black pen
  cp5.addRadioButton("penColorRadiobutton")
    .setLabel("Pen color")
    .setPosition(xx, yy)
    .setColorLabel(color(127))
    .setSize(h0, h0)
    .setItemsPerRow(1)
    .setLabelPadding(10,10)
    .addItem("Black Pen", PENCOLORMODE_BLACK)
    .addItem("White Pen", PENCOLORMODE_WHITE)
    .addItem("Color Pens", PENCOLORMODE_COLORS)
    .activate(penColorMode)
    .setNoneSelectedAllowed(false) // always have 1 item selected
    ;
  yy += (h0 + s0) * 3;

  // Create a new slider to set distance between rings: default value is 5
  yy += t0; // need spece for the label
  cp5.addSlider("distanceSlider")
    .setBroadcast(false)
    .setLabel("Distance between rings")
    .setRange(5, 10)
    .setValue(5)
    .setNumberOfTickMarks(6)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setSliderMode(Slider.FLEXIBLE)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);
  // Reposition the Label for controller 'slider'
  cp5.getController("distanceSlider").getCaptionLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setColor(color(128));

  // Create a new slider to set density: default value is 75
  yy += t0; // need spece for the label
  cp5.addSlider("densitySlider")
    .setBroadcast(false)
    .setLabel("Density")
    .setRange(36, 180)
    .setValue(density)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setSliderMode(Slider.FLEXIBLE)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);
  // Reposition the Label for controller 'slider'
  cp5.getController("densitySlider").getCaptionLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setColor(color(128));

  yy += t0; // some space for grouping

  // Create a numberbox to set centerpoint
  cp5.addNumberbox("cernterPointXNumberbox")
    .setLabel("Center X")
    .setBroadcast(false)
    .setRange(0, INTERNAL_IMAGE_SIZE - 1)
    .setPosition(xx, yy)
    .setSize(w0 / 2, h0)
    .setScrollSensitivity(1.1)
    .setDirection(Controller.HORIZONTAL) // change the control direction to left/right
    .setValue(centerPointX)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);
  // Reposition the Label for controller 'slider'
  cp5.getController("cernterPointXNumberbox").getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(10).setColor(color(128));

  // Create a numberbox to set centerpoint
  cp5.addNumberbox("cernterPointYNumberbox")
    .setLabel("Center Y")
    .setBroadcast(false)
    .setRange(0, INTERNAL_IMAGE_SIZE - 1)
    .setPosition(xx, yy)
    .setSize(w0 / 2, h0)
    .setScrollSensitivity(1.1)
    .setDirection(Controller.HORIZONTAL) // change the control direction to left/right
    .setValue(centerPointY)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);
  // Reposition the Label for controller 'slider'
  cp5.getController("cernterPointYNumberbox").getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(10).setColor(color(128));

  // Create a toggle to enable/disable live preview: default is false
  cp5.addToggle("useCircleSwitch")
    .setLabel("Circle Shape")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(h0, h0)
    .setValue(useCircleShape)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);
  // Reposition the Label for controller 'toggle'
  cp5.getController("useCircleSwitch").getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(10).setColor(color(128));

  yy += t0; // some space for grouping

  // Create a toggle to enable/disable live preview: default is true
  cp5.addToggle("previewSwitch")
    .setLabel("Live Preview")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(h0, h0)
    .setValue(usePreview)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);
  // Reposition the Label for controller 'toggle'
  cp5.getController("previewSwitch").getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(10).setColor(color(128));

  // Skip
  yy += (h0 + s0);

  // Create a new button with name 'saveAsSVGButton'
  cp5.addButton("saveAsSVGButton")
    .setLabel("Save As SVG")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);

  // Create a new button with name 'saveAsPDFButton'
  cp5.addButton("saveAsPDFButton")
    .setLabel("Save As PDF")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);

  // Reset position for next raw
  yy = y0;
  xx = x0 + 150;

  // Create a new text field to show feedback from the controller
  feedbackText = cp5.addTextarea("feedback")
    .setSize(canvasWidth, h0 * 2)
    .setText("Load image to start")
    //.setFont(createFont("arial", 12))
    .setLineHeight(14)
    .setColor(color(128))
    .setColorBackground(color(235, 100))
    .setColorForeground(color(245, 100))
    .setPosition(xx, yy)
    ;
}

// Button control event handler
public void controlEvent(ControlEvent theEvent) {
  //println(theEvent.getController().getName());
}

// Button Event - Open: Open image file dialogue
public void openFileButton(int theValue) {
  selectInput("Select a file to process:", "fileSelected");
}
// Opens input file selection window and draws selected image to screen
void fileSelected(File selection) {
  if (selection == null) {
    return;
  }

  String locImg = selection.getAbsolutePath();
  // Check to see if the format is supported
  // https://processing.org/reference/loadImage_.html
  String ext = locImg.substring(locImg.lastIndexOf(".") + 1).toLowerCase();
  if (!ext.equals("gif")
    && !ext.equals("jpg") && !ext.equals("jpeg")
    && !ext.equals("tga")
    && !ext.equals("png")) {
    feedbackText.setText(locImg + " is not supported format");
    feedbackText.update();
    return;
  }

  sourceImg = loadImage(locImg);
  feedbackText.setText(locImg + " was succesfully opened");
  feedbackText.update();
  resizeImg();
  displayImg = loadImage(locImg);
  resizedisplayImg();

  centerPointX = sourceImg.width / 2;
  centerPointY = sourceImg.height / 2;
  updateEndRadius();
  // update GUI parts
  cp5.getController("cernterPointXNumberbox").setValue(centerPointX);
  cp5.getController("cernterPointXNumberbox").setMax(float(sourceImg.width - 1));
  cp5.getController("cernterPointYNumberbox").setValue(centerPointY);
  cp5.getController("cernterPointYNumberbox").setMax(float(sourceImg.height - 1));

  // Everything went well.
  sourceImgPath = locImg;
  isLoaded = true;

  if (usePreview) {
    needToUpdatePreview = true;
  } else {
    needToDrawOriginalImage = true;
  }
}

// Button Event - generateSpiral: Convert image file to SVG
public void generateSpiralButton(int theValue) {
  if (!isLoaded) {
    return;
  }
  needToUpdatePreview = true;
}

// Display loaded images
public void viewOriginalButton(int theValue) {
  if (!isLoaded) {
    return;
  }
  needToDrawOriginalImage = true;
}

public void penColorRadiobutton(int theValue) {
  if (theValue == penColorMode) {
    return;
  }
  penColorMode = theValue;
  updateCanvasColor();
  if (isLoaded && usePreview) {
    needToUpdatePreview = true;
  }
}

// Recieve wave distance value from slider
public void distanceSlider(int theValue) {
  distance = theValue;
  if (isLoaded && usePreview) {
    needToUpdatePreview = true;
  }
}

// Recieve density value from slider
public void densitySlider(int theValue) {
  density = theValue;
  if (isLoaded && usePreview) {
    needToUpdatePreview = true;
  }
}

// Recieve center X value from numberbox
public void cernterPointXNumberbox(int theValue) {
  centerPointX = theValue;
  updateEndRadius();
  if (isLoaded && usePreview) {
    needToUpdatePreview = true;
  }
}

// Recieve center Y value from numberbox
public void cernterPointYNumberbox(int theValue) {
  centerPointY = theValue;
  updateEndRadius();
  if (isLoaded && usePreview) {
    needToUpdatePreview = true;
  }
}

// Whether to make the data shape a circle or not
public void useCircleSwitch(boolean theValue) {
  useCircleShape = theValue;
  if (!isLoaded) {
    return;
  }
  updateEndRadius();
  if (usePreview) {
    needToUpdatePreview = true;
  }
}

// Change preview mode
public void previewSwitch(boolean theValue) {
  usePreview = theValue;
  if (!isLoaded) {
    return;
  }
  if (usePreview) {
    needToUpdatePreview = true;
  }
}

// File path utils
String createOutputFilename(String basePath, String ext) {
  // get the filename of the image and remove the extension
  // No check if extension exists
  File file = new File(basePath);
  String imageName = file.getName();
  imageName = imageName.substring(0, imageName.lastIndexOf("."));
  return imageName + "." + ext;
}

// Save the spiral in the specified format
void saveAs(String format) {
  if (!isLoaded) {
    feedbackText.setText("no image file is currently open!");
    feedbackText.update();
    return;
  }

  // Construct filename
  String ext = "";
  if (format.equals(PDF)) {
    ext = "pdf";
  } else if (format.equals(SVG)) {
    ext = "svg";
  } else {
    feedbackText.setText("format \"" + format + "\"" + " is not supported!");
    feedbackText.update();
    return;
  }
  String fileName = createOutputFilename(sourceImgPath, ext);

  needToUpdatePreview = false;

  // Update spiral by current parameter
  updateOutputSpiral();

  // Prepare
  int w = sourceImg.width;
  int h = sourceImg.height;
  if (useCircleShape) {
    w = int(endRadius * 2) - 1;
    h = int(endRadius * 2) - 1;
  }

  // Draw it!
  PGraphics pg = createGraphics(w, h, format, fileName);
  pg.beginDraw();
  pg.noStroke();
  pg.fill(canvasColor);
  if (useCircleShape) {
    pg.translate(endRadius - centerPointX, endRadius - centerPointY);
    pg.circle(centerPointX, centerPointY, w);
  } else {
    pg.rect(0, 0, w, h);
  }
  if (penColorMode == PENCOLORMODE_COLORS) {
    if (format.equals(PDF)) {
      // PDFwriter does not support blendMode(MULTIPLY).
      // write the split image to the individual pages.
      pg.shape(outputSpiralC);
      ((PGraphicsPDF)pg).nextPage();
      pg.shape(outputSpiralM);
      ((PGraphicsPDF)pg).nextPage();
      pg.shape(outputSpiralY);
    } else {
      pg.blendMode(MULTIPLY); // It doesn't work with SVG, but I'll give it a try.
      pg.shape(outputSpiralC);
      pg.shape(outputSpiralM);
      pg.shape(outputSpiralY);
      pg.blendMode(BLEND);
    }
  } else {
    pg.shape(outputSpiral);
  }
  pg.dispose();
  pg.endDraw();

  // Done.
  feedbackText.setText("saved as " + sketchPath(fileName));
  feedbackText.update();

  needToUpdatePreview = true;
}

// Save As SVG
public void saveAsSVGButton(int theValue) {
  saveAs(SVG);
}

// Save As PDF
public void saveAsPDFButton(int theValue) {
  saveAs(PDF);
}

// Update Canvas Color
void updateCanvasColor() {
  if (penColorMode == PENCOLORMODE_WHITE) {
    canvasColor = color(0);
  } else {
    canvasColor = color(255);
  }
}

// Redraw background elements
void drawBackground() {
  noStroke();
  background(235);
  fill(245);
  rect(25, 25, 100 + guiBorder * 2, 25 + DISPLAY_IMAGE_SIZE + 25 * 2);
  fill(245);
  rect(175, 25, DISPLAY_IMAGE_SIZE + guiBorder * 2, 25 + DISPLAY_IMAGE_SIZE + 25 * 2);
  clearCanvas();
}

void clearCanvas() {
  // Draw a checkered pattern
  final int gridWidth = 10;
  int c[] = {
      // checker colors
      color(0xe4, 0xe4, 0xf0),  // dark
      color(0xec, 0xec, 0xf0)   // light
    };

  noStroke();
  int base = 0;
  for (int y = 0; y < canvasHeight; y += gridWidth) {
    int n = base;
    for (int x = 0; x < canvasWidth; x += gridWidth) {
      fill(c[n]);
      rect(CANVAS_ORIGIN_X + x, CANVAS_ORIGIN_Y + y, gridWidth, gridWidth);
      n ^= 1;
    }
    base ^= 1;
  }
}

void drawFrame() {
    if (!isLoaded) {
      return;
    }
    // Draw guide frame around the original image
    noFill();
    stroke(guideFrameColor);
    rect(CANVAS_ORIGIN_X, CANVAS_ORIGIN_Y, displayImg.width - 1, displayImg.height - 1); // -1 needed
}

// Utility functions
PShape startSpiralStroke(color c) {
  PShape s = createShape();
  s.setStroke(true);
  s.setFill(false);
  s.setStrokeJoin(ROUND);
  s.beginShape();
  s.stroke(c);
  return s;
}

void drawSpiralStroke(PShape s, float xa, float ya, float xb, float yb) {
  s.vertex(xa, ya);
  s.vertex(xb, yb);
}

void endSpiralStroke(PShape s, PShape parent) {
  s.endShape();
  parent.addChild(s);
}

// Callback interface for various brightness converters
public interface CalcBrightness {
  // Convert color value to brightness
  float calc(color c);
}

//
// Function to create spiral shape from loaded image file - Transparency zero work as a mask colour
//
PShape createSpiral(CalcBrightness brightnessCallback, color drawColor) {
  if (!isLoaded) {
    return null;
  }
  PShape parent = createShape(GROUP);
  // Calculates the first point
  float delta;
  float degree = density * 2 / (distance / 2);
  float radius = distance / (360 / degree);
  float rad = radians(degree);

  parent = createShape(GROUP);
  PShape s = createShape();
  boolean shapeOn = false; // Keeps track of a shape is open or closed
  while ((radius + distance / 2) < endRadius) {  // Have we reached the far corner of the image?
    float x = radius * cos(rad) + centerPointX;
    float y = -radius * sin(rad) + centerPointY;

    // Get the color and brightness of the sampled pixel
    color c = sourceImg.get(int(x), int(y)); // Sampled color
    float a = alpha(c);                      // Sampled alpha (transparency 0 .. 255)

    // Are we within the the image?
    // If so check if the shape is open. If not, open it
    if ((a != 0.0)
      && (x > distance / 2) && ((x + distance / 2) < sourceImg.width)
      && (y > distance / 2) && ((y + distance / 2) < sourceImg.height)) {
      float b = brightnessCallback.calc(c);
      // Move up according to sampled brightness
      float aradius = radius + b; // Radius with brighness applied up
      float xa =  aradius * cos(rad) + centerPointX;
      float ya = -aradius * sin(rad) + centerPointY;

      // Move down according to sampled brightness
      delta = density / radius;
      degree += delta;
      radius += distance / (360 / delta);
      rad = radians(degree);

      float bradius = radius - b; // Radius with brighness applied down
      float xb =  bradius * cos(rad) + centerPointX;
      float yb = -bradius * sin(rad) + centerPointY;

      // Add vertices to shape
      if (shapeOn == false) {
        s = startSpiralStroke(drawColor);
        shapeOn = true;
      }
      // Draw lines (from previous (xb, yb) to (xa, ya), then from (xa, ya) to (xb, yb)
      drawSpiralStroke(s, xa, ya, xb, yb);
    } else {
      // We are outside of the image or transparency is zero, so close the shape if it is open
      if (shapeOn) {
        endSpiralStroke(s, parent);
        shapeOn = false;
      }
    }
    // Next
    delta = density / radius;
    degree += delta;
    radius += distance / (360 / delta);
    rad = radians(degree);
  }

  // end of loop
  if (shapeOn) {
    endSpiralStroke(s, parent);
  }

  return parent;
}

void updateOutputSpiral() {
  if (!isLoaded) {
    return;
  }

  if (penColorMode == PENCOLORMODE_BLACK) {
    // draw with black stroke (it is managed by public variable)
    outputSpiral = createSpiral((c) -> map(brightness(c), 0, 255, distance / 2, 0), color(0));
  } else if (penColorMode == PENCOLORMODE_WHITE) {
    // draw with white stroke (it is managed by public variable)
    outputSpiral = createSpiral((c) -> map(brightness(c), 0, 255, 0, distance / 2), color(255));
  } else if (penColorMode == PENCOLORMODE_COLORS) {
    // draw with CMY strokes (these are managed by public variables)
    outputSpiralC = createSpiral((c) -> map(red(c), 0, 255, distance / 2, 0), color(0,255,255)); // no red
    outputSpiralM = createSpiral((c) -> map(green(c), 0, 255, distance / 2, 0), color(255,0,255)); // no green
    outputSpiralY = createSpiral((c) -> map(blue(c), 0, 255, distance / 2, 0), color(255,255,0)); // no blue

    PShape parent = createShape(GROUP);
    parent.addChild(outputSpiralC);
    parent.addChild(outputSpiralM);
    parent.addChild(outputSpiralY);

    // replace
    outputSpiral = parent;
  } else {
    ; // invalid mode
  }
}

void drawSpiral() {
  if (!isLoaded) {
    return;
  }

  if (penColorMode != PENCOLORMODE_BLACK && penColorMode != PENCOLORMODE_WHITE && penColorMode != PENCOLORMODE_COLORS) {
    return;
  }

  // Draw
  pushMatrix();

  // Scaling
  translate(CANVAS_ORIGIN_X, CANVAS_ORIGIN_Y);
  scale(SCALE_RATIO);

  // Draw background shape
  noStroke();
  fill(canvasColor);
  if (useCircleShape) {
    circle(centerPointX, centerPointY, int(endRadius * 2) - 1);
  } else {
    rect(0, 0, sourceImg.width, sourceImg.height);
  }

  // Draw spiral shape
  if (penColorMode == PENCOLORMODE_COLORS) {
    blendMode(MULTIPLY);
    shape(outputSpiralC);
    shape(outputSpiralM);
    shape(outputSpiralY);
    blendMode(BLEND);
  } else if (penColorMode == PENCOLORMODE_BLACK || penColorMode == PENCOLORMODE_WHITE) {
    shape(outputSpiral);
  } else {
    ; // invalid mode
  }

  popMatrix();
}

void resizeImg() {
  if (sourceImg.width > sourceImg.height) {
    sourceImg.resize(INTERNAL_IMAGE_SIZE, 0);
  } else {
    sourceImg.resize(0, INTERNAL_IMAGE_SIZE);
  }
}

void resizedisplayImg() {
  if (displayImg.width > displayImg.height) {
    displayImg.resize(canvasWidth, 0);
  } else {
    displayImg.resize(0, canvasHeight);
  }
}

void drawOriginalImage() {
  image(displayImg, CANVAS_ORIGIN_X, CANVAS_ORIGIN_Y);
}

//
// Centerpoint functions
//

void updateEndRadius() {
  if (useCircleShape) {
    endRadius = getMinRadius();
  } else {
    endRadius = getMaxRadius();
  }
}

float getMaxRadius() {
  // Search the far corner of the image
  //
  // r0 | r1
  //----+----
  // r2 | r3
  float r0 = sqrt(pow(centerPointX, 2) + pow(centerPointY, 2));
  float r1 = sqrt(pow(sourceImg.width - 1 - centerPointX, 2) + pow(centerPointY, 2));
  float r2 = sqrt(pow(centerPointX, 2) + pow(sourceImg.height - 1 - centerPointY, 2));
  float r3 = sqrt(pow(sourceImg.width - 1 - centerPointX, 2) + pow(sourceImg.height - 1 - centerPointY, 2));
  return (float)Math.floor(max(max(r0, r1), max(r2, r3)));
}

float getMinRadius() {
  // Search the nearest edge of the image
  float r0 = centerPointX;
  float r1 = centerPointY;
  float r2 = sourceImg.height - 1 - centerPointY;
  float r3 = sourceImg.width - 1 - centerPointX;
  return (float)Math.floor(min(min(r0, r1), min(r2, r3)));
}

//
// Process mouse events
//

boolean inCanvas() {
  return(mouseX >= CANVAS_ORIGIN_X && mouseX < (CANVAS_ORIGIN_X + displayImg.width) &&
    mouseY >= CANVAS_ORIGIN_Y && mouseY < (CANVAS_ORIGIN_Y + displayImg.height));
}

boolean mouseLocked = false;

void mousePressed() {
  if (!isLoaded) {
    return;
  }

  if (mouseButton == LEFT) {
    if (inCanvas()) {
      mouseLocked = true;
      centerPointX = int(float(mouseX - CANVAS_ORIGIN_X) / SCALE_RATIO);
      centerPointY = int(float(mouseY - CANVAS_ORIGIN_Y) / SCALE_RATIO);
      // update GUI parts
      cp5.getController("cernterPointXNumberbox").setValue(centerPointX);
      cp5.getController("cernterPointYNumberbox").setValue(centerPointY);

      updateEndRadius();
      if (usePreview) {
        needToUpdatePreview = true;
      }
      return;
    } else {
      mouseLocked = false;
    }
  }
}

void mouseReleased() {
  if (mouseButton == LEFT) {
    mouseLocked = false;
  }
}
