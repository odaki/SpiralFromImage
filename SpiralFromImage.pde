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

import controlP5.*;                        // CP5 for gui
import java.io.File;                       // Required for file path operations

import processing.svg.*;
import processing.pdf.*;

ControlP5 cp5;

Textarea feedbackText;

final int internalImgSize = 1200;
final int displayImgSize = 600;

String sourceImgPath = "";                 // Source image absolute location
boolean isLoaded = false;                  // Whether the source image has been loaded or not
PImage sourceImg;                          // Source image for conversion
PImage displayImg;                         // Image to use as display

float distance = 5;                        // Distance between rings
float density = 36;                        // Density
int centerPointX = internalImgSize / 2;    // Center point of spiral
int centerPointY = internalImgSize / 2;    // Center point of spiral
float endRadius = internalImgSize / 2;     // Largest value the spiral needs to cover the image
PShape outputSpiral;                       // Spriral shape to draw

boolean useCircleShape = false;
boolean usePreview = true;
boolean needToUpdatePreview = false;

int canvasOriginX = 187;
int canvasOriginY = 85;
int guiBorder = 12;

int canvasWidth = displayImgSize;
int canvasHeight = displayImgSize;

void settings() {
  size(174 + displayImgSize + 25 * 2, 75 + displayImgSize + 25 * 2);
}

void setup() {
  drawBackground();
  outputSpiral = createShape(GROUP);
  setupGUI();
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

  // Create a new button with name 'generateSpiralButton'
  cp5.addButton("generateSpiralButton")
    .setLabel("Generate Spiral")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);

  // Create a new button with name 'clearDisplay'
  cp5.addButton("clearDisplayButton")
    .setLabel("Clear Display")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);

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
    .setRange(0, internalImgSize - 1)
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
    .setRange(0, internalImgSize - 1)
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
    clearCanvas();
    drawImg();
  }
}

// Button Event - generateSpiral: Convert image file to SVG
public void generateSpiralButton(int theValue) {
  if (!isLoaded) {
    feedbackText.setText("no image file is currently open!");
    feedbackText.update();
    return;
  }
  needToUpdatePreview = true;
}

// Clear the display of any loaded images
public void clearDisplayButton(int theValue) {
  if (!isLoaded) {
    clearDisplay();
    return;
  }
  clearCanvas();
  drawImg();
}

// Recieve wave distance value from slider
public void distanceSlider(int theValue) {
  distance = theValue;
  if (usePreview) {
    needToUpdatePreview = true;
  }
}

// Recieve density value from slider
public void densitySlider(int theValue) {
  density = theValue;
  if (usePreview) {
    needToUpdatePreview = true;
  }
}

// Recieve center X value from numberbox
public void cernterPointXNumberbox(int theValue) {
  centerPointX = theValue;
  updateEndRadius();
  if (usePreview) {
    needToUpdatePreview = true;
  }
}

// Recieve center Y value from numberbox
public void cernterPointYNumberbox(int theValue) {
  centerPointY = theValue;
  updateEndRadius();
  if (usePreview) {
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
  drawSpiral();

  // Prepare
  int w = sourceImg.width;
  int h = sourceImg.height;
  if (useCircleShape) {
    w = int(endRadius * 2) + 1;
    h = int(endRadius * 2) + 1;
  }

  // Draw it!
  PGraphics pg = createGraphics(w, h, format, fileName);
  pg.beginDraw();
  if (useCircleShape) {
    pg.translate(endRadius - centerPointX, endRadius - centerPointY);
  }
  pg.shape(outputSpiral);
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

// Redraw background elements to remove previous loaded PImage
void drawBackground() {
  noStroke();
  background(235);
  fill(245);
  rect(25, 25, 100 + guiBorder * 2, 25 + displayImgSize + 25 * 2);
  fill(245);
  rect(175, 25, displayImgSize + guiBorder * 2, 25 + displayImgSize + 25 * 2);
}

void clearCanvas() {
  noStroke();
  fill(245);
  rect(canvasOriginX - 12, canvasOriginY - 10, 12 + canvasWidth + 12, 10 + canvasHeight + 10);
}

void draw() {
  if (needToUpdatePreview) {
    needToUpdatePreview = false;
    drawSpiral();
  }
}

// Function to creatve spiral shape from loaded image file - Transparency zero work as a mask colour
void drawSpiral() {
  if (!isLoaded) {
    return;
  }

  // Calculates the first point
  float delta;
  float degree = density * 2 / (distance / 2);
  float radius = distance / (360 / degree);
  float rad = radians(degree);

  outputSpiral = createShape(GROUP);
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
    if ((a != 0.0) && (x >= 0) && (x < sourceImg.width) && (y >= 0) && (y < sourceImg.height)) {
      float b = map(brightness(c), 0, 255, distance / 2, 0); // Sampled brightness
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
        s = createShape();
        s.setStroke(true);
        s.setFill(false);
        s.setStrokeJoin(ROUND);
        s.beginShape();
        shapeOn = true;
      }
      s.vertex(xa, ya);
      s.vertex(xb, yb);
    } else {
      // We are outside of the image or transparency is zero, so close the shape if it is open
      if (shapeOn) {
        s.endShape();
        outputSpiral.addChild(s);
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
    s.endShape();
    outputSpiral.addChild(s);
  }

  displaySVG();

  System.gc();
}

void displaySVG() {
  clearCanvas();

  pushMatrix();
  translate(canvasOriginX, canvasOriginY);
  scale(float(displayImgSize) / float(internalImgSize));
  shape(outputSpiral);
  popMatrix();
}

void resizeImg() {
  if (sourceImg.width > sourceImg.height) {
    sourceImg.resize(internalImgSize, 0);
  } else {
    sourceImg.resize(0, internalImgSize);
  }
}

void resizedisplayImg() {
  if (displayImg.width > displayImg.height) {
    displayImg.resize(canvasWidth, 0);
  } else {
    displayImg.resize(0, canvasHeight);
  }
}

void drawImg() {
  set(canvasOriginX, canvasOriginY, displayImg);
}

void clearDisplay() {
  background(235);
  drawBackground();
  if (!isLoaded) {
    feedbackText.setText("Load image to start");
  }
  System.gc();
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
  float r0 = sqrt(pow(centerPointX + 1, 2) + pow(centerPointY + 1, 2));
  float r1 = sqrt(pow(sourceImg.width - centerPointX, 2) + pow(centerPointY + 1, 2));
  float r2 = sqrt(pow(centerPointX + 1, 2) + pow(sourceImg.height - centerPointY, 2));
  float r3 = sqrt(pow(sourceImg.width - centerPointX, 2) + pow(sourceImg.height - centerPointY, 2));
  return max(max(r0, r1), max(r2, r3));
}

float getMinRadius() {
  // Search the nearest edge of the image
  float r0 = centerPointX + 1;
  float r1 = centerPointY + 1;
  float r2 = sourceImg.height - centerPointY;
  float r3 = sourceImg.width - centerPointX;
  return min(min(r0, r1), min(r2, r3));
}

//
// Process mouse events
//

boolean inCanvas() {
  return(mouseX >= canvasOriginX && mouseX < (canvasOriginX + displayImg.width) &&
    mouseY >= canvasOriginY && mouseY < (canvasOriginY + displayImg.height));
}

boolean mouseLocked = false;

void mousePressed() {
  if (!isLoaded) {
    return;
  }

  if (mouseButton == LEFT) {
    if (inCanvas()) {
      mouseLocked = true;
      centerPointX = int(float(mouseX - canvasOriginX) * float(internalImgSize) / float(displayImgSize));
      centerPointY = int(float(mouseY - canvasOriginY) * float(internalImgSize) / float(displayImgSize));
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
