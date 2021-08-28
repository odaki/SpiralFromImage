/**
 SpiralfromImage
 Copyright Jan Krummrey 2016
 
 Idea taken from Norwegian Creations Drawbot
 http://www.norwegiancreations.com/2012/04/drawing-machine-part-2/
 
 The sketch takes an image and turns it into a modulated spiral.
 Dark parts of the image have larger amplitudes.
 The result is being writen to a PDF for refinement in Illustrator/Inkscape
 
 Version 1.0 Buggy PDF export
 1.1 added SVG export and flag to swith off PDF export
 1.2 removed PDF export
     added and reworked CP5 gui (taken from max_bol's fork)
     fixed wrong SVG header
 
 Todo:
 - Choose centerpoint with mouse or numeric input
 
 SpiralfromImage is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with SpiralfromImage.  If not, see <http://www.gnu.org/licenses/>.
 
 jan@krummrey.de
 http://jan.krummrey.de
 */

import controlP5.*;                        // CP5 for gui
import java.io.File;                       // For file import and export

ControlP5 cp5;
File file;

Textarea feedbackText;
String locImg = "";                        // Source image absolute location
PImage sourceImg;                          // Source image for svg conversion
PImage displayImg;                         // Image to use as display
float dist = 5;                            // Distance between rings
float density = 75;                        // Density
float ampScale = 2.4;                      // Controls the amplitude
float endRadius;                           // Largest value the spiral needs to cover the image
color mask = color (255, 255, 255);        // This color will not be drawn (WHITE)
PShape outputSVG;                          // SVG shape to draw
String outputSVGName;                      // Filename of the generated SVG
String imageName;                          // Filename of the loaded image

boolean usePreview = true;
PShape previewShape;
boolean needToUpdatePreview = false;

void setup() {
  size(1024, 800);
  drawBackground();
  previewShape = createShape(GROUP);

  cp5 = new ControlP5(this);

  final int x0 = 37;  // parts align x
  final int y0 = 37;  // parts align y
  final int h0 = 19;  // parts height
  final int w0 = 100; // parts width
  final int s0 = 6;   // parts spacing
  final int t0 = 12;  // label height

  int xx = x0;
  int yy = y0;

  // create a new button with name 'Open'
  cp5.addButton("openFileButton")
    .setLabel("Open File")
    .setBroadcast(false)
    .setPosition(x0, yy)
    .setSize(w0, h0)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);
  
  // create a new button with name 'Generate Spiral'
  cp5.addButton("generateSpiralButton")
    .setLabel("Generate Spiral")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);
  
  // create a new button with name 'clearDisplay'
  cp5.addButton("clearDisplayButton")
    .setLabel("Clear Display")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);
  
  // create a new slider to set amplitude of waves drawn: default value is 2.4
  yy += t0; // need spece for the label
  cp5.addSlider("amplitudeSlider")
    .setBroadcast(false)
    .setLabel("Wave amplitude")
    .setRange(1, 8)
    .setValue(2.4)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setSliderMode(Slider.FLEXIBLE)
    .setDecimalPrecision(1)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);
  // reposition the Label for controller 'slider'
  cp5.getController("amplitudeSlider").getCaptionLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setColor(color(128));

  //create a new slider to set distance between rings: default value is 5
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
  // reposition the Label for controller 'slider'
  cp5.getController("distanceSlider").getCaptionLabel().align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setColor(color(128));

  // create a toggle and change the default look to a (on/off) switch look
  cp5.addToggle("previewSwitch")
    .setLabel("Live Preview")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(h0, h0)
    .setValue(usePreview)
    .setBroadcast(true)
    ;
  yy += (h0 + s0);
  // reposition the Label for controller 'toggle'
  cp5.getController("previewSwitch").getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(10).setColor(color(128));

  // skip
  yy += (h0 + s0);

  // create a new button with name 'Generate'
  cp5.addButton("saveAsSVGButton")
    .setLabel("Save As SVG")
    .setBroadcast(false)
    .setPosition(xx, yy)
    .setSize(w0, h0)
    .setBroadcast(true)
    ;

  // reset position for next raw
  yy = y0;
  xx = x0 + 150;

  //create a new text field to show feedback from the controller
  feedbackText = cp5.addTextarea("feedback")
    .setSize(512, h0 * 2)
    .setText("Load image to start")
    //.setFont(createFont("arial", 12))
    .setLineHeight(14)
    .setColor(color(128))
    .setColorBackground(color(235, 100))
    .setColorForeground(color(245, 100))
    .setPosition(xx, yy)
    ;
}

//Button control event handler
public void controlEvent(ControlEvent theEvent) {
  //println(theEvent.getController().getName());
}

// Button Event - Open: Open image file dialogue
public void openFileButton(int theValue) {
  selectInput("Select a file to process:", "fileSelected");
}

// Button Event - generateSpiral: Convert image file to SVG
public void generateSpiralButton(int theValue) {
  if (locImg == "") {
    feedbackText.setText("no image file is currently open!");
    feedbackText.update();
    return;
  }
  needToUpdatePreview = true;
} //<>//

// Clear the display of any loaded images
public void clearDisplayButton(int theValue) {
  if (locImg == "") {
    clearDisplay();
    return;
  }
  clearCanvas();
  drawImg();
}

//Recieve amplitude value from slider
public void amplitudeSlider(float theValue) {
  ampScale = theValue;
  //println(ampScale);
  if (usePreview) {
    needToUpdatePreview = true;
  }
}

//Recieve wave distance value from slider
public void distanceSlider(int theValue) {
  dist = theValue;
  //println(dist);
  if (usePreview) {
    needToUpdatePreview = true;
  }
}

// Change preview mode
public void previewSwitch(boolean theValue) {
  usePreview = theValue;
  if (locImg == "") {
    return;
  }
  if (usePreview) {
    needToUpdatePreview = true;
  }
}

// Save As SVG
public void saveAsSVGButton(int theValue) {
  if (locImg == "") {
    feedbackText.setText("no image file is currently open!");
    feedbackText.update();
    return;
  }
  needToUpdatePreview = false;
  drawSVG(true); // true means save file
}

//Redraw background elements to remove previous loaded PImage
void drawBackground () {
  noStroke();
  background(235);
  fill(245);
  rect(25, 25, 125, 750);
  fill(245);
  rect(175, 25, 537, 750);
}

void clearCanvas() {
  noStroke();
  fill(245);
  rect(175, 75+3, 537, 700-3);
}

void draw() {
  if (needToUpdatePreview) {
    needToUpdatePreview = false;
    drawSVG(false);
  }
}

//Opens input file selection window and draws selected image to screen
void fileSelected(File selection) {
  if (selection == null) {
    return;
  }

  locImg=selection.getAbsolutePath();
  feedbackText.setText(locImg+" was succesfully opened");
  feedbackText.update();
  sourceImg=loadImage(locImg);
  resizeImg();
  displayImg=loadImage(locImg);

  // get the filename of the image and remove the extension
  // No check if extension exists
  // TODO: extract path to save SVG to later
  file = new File(locImg);
  imageName = file.getName();
  imageName = imageName.substring(0, imageName.lastIndexOf("."));
  outputSVGName = imageName+".svg";

  if (usePreview) {
    needToUpdatePreview = true;
  } else {
    clearCanvas();
    drawImg();
  }
}

// Function to creatve SVG file from loaded image file - Transparencys currently do not work as a mask colour
void drawSVG(boolean isSave) {
  color c;                                   // Sampled color
  float b;                                   // Sampled brightness
  float radius = dist/2;                     // Current radius
  float aradius;                             // Radius with brighness applied up
  float bradius;                             // Radius with brighness applied down
  float alpha;                               // Initial rotation
  float x, y, xa, ya, xb, yb;                // current X and y + jittered x and y
  float k;                                   // current radius
  if (locImg == "") {
    return;
  }
  
  // Calculates the first point
  // currently just the center
  // TODO: create button to set center with mouse
  k = density/radius;
  alpha = k;
  radius += dist/(360/k);

  // when have we reached the far corner of the image?
  // TODO: this will have to change if not centered
  endRadius = sqrt(pow((sourceImg.width/2), 2)+pow((sourceImg.height/2), 2));

  if (isSave) {
    openSVG ();
  }
  previewShape = createShape(GROUP);
  PShape s = createShape();

  // Have we reached the far corner of the image?
  while (radius < endRadius) {
    k = (density/2)/radius ;
    alpha += k;
    radius += dist/(360/k);
    x =  radius*cos(radians(alpha))+sourceImg.width/2;
    y = -radius*sin(radians(alpha))+sourceImg.height/2;

    // Are we within the the image?
    // If so check if the shape is open. If not, open it
    if ((x>=0) && (x<sourceImg.width) && (y>=0) && (y<sourceImg.height)) {

      // Get the color and brightness of the sampled pixel
      c = sourceImg.get (int(x), int(y));
      b = brightness(c);
      b = map (b, 0, 255, dist*ampScale, 0);

      // Move up according to sampled brightness
      aradius = radius+(b/dist);
      xa =  aradius*cos(radians(alpha))+sourceImg.width/2;
      ya = -aradius*sin(radians(alpha))+sourceImg.height/2;

      // Move down according to sampled brightness
      k = (density/2)/radius ;
      alpha += k;
      radius += dist/(360/k);
      bradius = radius-(b/dist);
      xb =  bradius*cos(radians(alpha))+sourceImg.width/2;
      yb = -bradius*sin(radians(alpha))+sourceImg.height/2;

      // If the sampled color is the mask color do not write to the shape
      if (mask == c) {
        if (shapeOn) {
          if (isSave) {
            closePolyline ();
            output.println("<!-- Mask -->");
          }
          s.endShape();
          previewShape.addChild(s);
          shapeOn = false;
        }
      } else {
        // Add vertices to shape
        if (shapeOn == false) {
          if (isSave) {
            openPolyline ();
          }
          s = createShape();
          s.setStroke(true);
          s.beginShape(LINES);
          shapeOn = true;
        }
        if (isSave) {
          vertexPolyline (xa, ya);
          vertexPolyline (xb, yb);
        }
        s.vertex(xa, ya);
        s.vertex(xb, yb);
      }
    } else {

      // We are outside of the image so close the shape if it is open
      if (shapeOn == true) {
        if (isSave) {
          closePolyline ();
          output.println("<!-- Out of bounds -->");
        }
        s.endShape();
        previewShape.addChild(s);
        shapeOn = false;
      }
    }
  }
  if (shapeOn) {
    if (isSave) {
      closePolyline ();
    }
    s.endShape();
    previewShape.addChild(s);
  }

  if (isSave) {
    closeSVG ();
    //println(locImg+" was processed and saved as "+outputSVGName);
    feedbackText.setText(locImg+" was processed and saved as "+sketchPath(outputSVGName));
    feedbackText.update();
  }

  displaySVG();

  System.gc();
}

void displaySVG() {
  clearCanvas();
  previewShape.scale(512.0/1200.0);
  shape(previewShape, 187, 85);
}

void resizeImg() {
  if ( sourceImg.width > sourceImg.height) {
    sourceImg.resize (1200, 0);
  } else {
    sourceImg.resize (0, 1200);
  }
}

void resizedisplayImg() {
  if ( displayImg.width > displayImg.height) {
    displayImg.resize (512, 0);
  } else {
    displayImg.resize (0, 512);
  }
}

void drawImg () {
  resizedisplayImg();
  set(187, 85, displayImg);
}

void clearDisplay() {
  background(235);
  drawBackground();
  if (locImg == "") {
    feedbackText.setText("Load image to start");
  }
  System.gc();
}
