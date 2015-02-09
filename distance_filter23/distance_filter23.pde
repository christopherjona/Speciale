import codeanticode.syphon.*;
import deadpixel.keystone.*;
SyphonServer server;
Keystone ks;
CornerPinSurface surface;
PGraphics offscreen;
/******************************************************************
 
 FILTERS THE KINECT IMAGE BASED ON A DISTANCE RANGE
 (ONLY SHOW OBJECTS BETWEEN 500-1500mm FOR INSTANCE)
 CAN BE USED AS A REPLACEMENT FOR BLUE- AND GREEN SCREEN TECHNIQUES
 
 Uses SimpleOpenNI (http://code.google.com/p/simple-openni/)
 
 Release v16-07-2013
 
 (c) 2012-2013 Rolf van Gelder, CAGE web design
 
 http://cagewebdev.com, info@cagewebdev.com
 
 ******************************************************************/
// KINECT INTERFACE
import SimpleOpenNI.*;
import processing.video.*;
int nb_movies=10; // amount of movies
Movie movie; // Defining array of movies 
int currentMovie=0; //variable that says in which state of the array you are at
boolean doitonce=false; //variable that makes us sure when the transition happens. False is the state when there is no one
int time = 0; //timereference when someone gets in the field
SimpleOpenNI simpleOpenNI;
// IMAGES
PImage maskImage; //Creating greytone image shades of grey. Body one color background another
PImage[] maskImages; //Creating greytone image shades of grey. Body one color background another
int mean_iterations = 1; // number of frames that are used for average (1:no effet / 2:little effect / 100:too much effect)
PImage cImage; // An image which is made from maskimage. One color and shades of transparency
// KINECT DEPTH VALUES
int[] depthValues; //realtime distance measuring from the camera
int[] depthBackground; //Background reference. Done once
// RADIUS FOR BLUR (PIXELS)
int blurRadius = 7;
//TIME AND VALUE FOR DRAWING WITH SILHOUET. SEE DRAW
 int minTime=5000; //Where it starts to spread more and more
 int maxTime=10000;//When it reaches the maximum spreading state
 int minValue=20;//How fast it vanishes in the maximum state 0 is never vanishing. 255 is vanishing instantly
// DISTANCE RANGE IN MILLIMETERS (FOR THE FILTER)
int minDistance  = 500;  // 50cm
int maxDistance  = 3000; // 4m
// SIZES
int canvasWidth  = displayWidth;
int canvasHeight = displayHeight;
int kinectWidth  = 640;
int kinectHeight = 480;
/*************************************************************
 
 INITIALIZATION
 
 *************************************************************/
void setup()
{
 
  size(displayWidth, displayHeight, P3D);
  server = new SyphonServer( this, "Processing Syphon" );
  ks = new Keystone(this);
  surface = ks.createCornerPinSurface(displayWidth, displayHeight, 20);
  offscreen = createGraphics(displayWidth, displayHeight, P3D);
  // NEW OPENNI CONTEXT INSTANCE
  simpleOpenNI = new SimpleOpenNI(this);
  
  // MIRROR THE KINECT IMAGE
  simpleOpenNI.setMirror(true);
  // ENABLE THE DEPTH MAP
  if (simpleOpenNI.enableDepth() == false)
  { // COULDN'T ENABLE DEPTH MAP
    println("Can't open the depthMap, maybe the Kinect is not connected!"); 
    exit();
    return;
  }
  movie = new Movie(this, "mov"+currentMovie+".mov");
  movie.loop();
  // MASK FOR MASKING THE MOVIE
  maskImage=createImage(kinectWidth, kinectHeight, RGB);
  for (int i=0; i<maskImage.pixels.length; i++)
    maskImage.pixels[i]=color(255);
    
  maskImages = new PImage[mean_iterations];
  for(int j=0;j<mean_iterations;j++){
    maskImages[j]=createImage(kinectWidth, kinectHeight, RGB);
    for (int i=0; i<maskImages[j].pixels.length; i++)
      maskImages[j].pixels[i]=color(255);
  }
  
  cImage = createImage(kinectWidth, kinectHeight, ARGB);
  frameRate(60);
  
  
  simpleOpenNI.update();
  depthValues=simpleOpenNI.depthMap();
  depthBackground=new int[depthValues.length];
  for(int i=0;i<depthValues.length;i++){
   depthBackground[i]=depthValues[i];
    if(depthBackground[i] == 0){
      depthBackground[i] = 10000;
    }  
  }
  
} // setup()
/*************************************************************
 
 INITIALIZE KINECT
 
 *************************************************************/
/*************************************************************
 
 PROCESSING LOOP
 
 *************************************************************/
void draw()
{
  //camera(0,-20,30,0,-40,70,0.0,0.0,1.0);
  for (int i=0; i<cImage.pixels.length; i++)
    cImage.pixels[i]=color(0,174,240); //Color of mask around silhouet. fokus cyan = (0,174,240) or white
    
  // UPDATE THE KINECT IMAGES
  simpleOpenNI.update();
  // GET DEPTH VALUES IN MILLIMETERS
  //depthValues=depthBackground;
  depthValues = simpleOpenNI.depthMap();
    for(int i=0;i<depthValues.length;i++){
    if(depthValues[i] == 0){
      depthValues[i] = 10000;
    }
    }
  for(int j=mean_iterations-1;j>0;j--){
     for(int i=0;i<depthValues.length;i++){
       maskImages[j].pixels[i]=maskImages[j-1].pixels[i];
     }
  }
  maskImages[0].loadPixels();
  boolean istheresomeone=false;
  float cnt=0;
  for (int pic = 0; pic < depthValues.length; pic++) {
    if (depthValues[pic] < (depthBackground[pic]-100) && depthValues[pic]<3000 && depthValues[pic]>1000 ) {
     
        maskImages[0].pixels[pic] = color(0);
        cnt++;
      } else {
          float val=red(maskImages[0].pixels[pic]);
          int drawTime=millis()-time;
          if(drawTime>minTime){
            if(drawTime<maxTime){
              val+=255-(drawTime-minTime)*(255-minValue)/(maxTime-minTime);
            }else{
              val+=minValue;
            }
            if(val>255) val=255;
          }else{
            val=255;
          }
          maskImages[0].pixels[pic] = color(val);;
        }
        //thread("putVolumeUp");
    }
  maskImages[0].updatePixels();
    

  if (cnt > 7000) istheresomeone=true;
          
  float vol=(cnt/depthValues.length);
  movie.volume(map(vol,0.15,0.23,0,1));
  //println(vol);
  
  for(int i=0;i<depthValues.length;i++){
    float mean_val=0;
    for(int j=0;j<mean_iterations;j++){
      mean_val+=red(maskImages[j].pixels[i]);
    }
    mean_val=mean_val/mean_iterations;
    maskImage.pixels[i]=(int)mean_val;
  }
  //maskImage.resize(width,height);
  if (istheresomeone) {
    if(doitonce==false){
      doitonce=true;
      time=millis(); //SETUP TIME ONCE
    }
    background(255); // background condition video
    if (movie.available()) {
      movie.read();
    }
 
 // image(movie, -(width/2), 0, height*1.25, height); //Use instead if adjust to vertical
  //  image(movies[currentMovie], -(width/2), 0, height*1.33, height);
  //  image(movies[currentMovie], 0, 0, width, height);
    
    if (blurRadius > 0) superFastBlur(blurRadius);
    cImage.mask(maskImage);
   // image(cImage, (-130)*1.5, (-50)*1.5, (displayWidth+130)*1.5, (displayHeight+50)*1.5); //Use instead if adjust to vertical
    
    //image(cImage,0,0,(displayWidth*1.5),(displayHeight*1.5));
    //    image(cImage,0,0,(displayWidth),(displayHeight)); //Size of silhouet
  }else{
    background(0);
    fill(255, 255, 255, 255);  
    rect(0, 0, displayWidth, displayHeight);
    if (doitonce==true) {
      doitonce=false;
      for (int i=0; i<cImage.pixels.length; i++)
        cImage.pixels[i]=color(255, 255, 255, 255);
      currentMovie+=1;
      if (currentMovie>=nb_movies) currentMovie=0;
      movie.stop(); 
      movie = new Movie(this, "mov"+currentMovie+".mov");
      movie.loop();
    }
  }
//mapping();
mapping1();
  }

  void mapping(){
    // Draw the scene, offscreen
  offscreen.beginDraw();
 offscreen.background(255);
 offscreen.image( simpleOpenNI.depthImage(), 0, 0, width, height);
 offscreen.image(movie, 0, 0, width, height);
 //   offscreen.image(movie, -(width/2), 0, height*1.25, height); //Use instead if adjust to vertical
// offscreen.image(movies[currentMovie], -(width/2), 0, height*1.33, height);
offscreen.image(cImage,0,0,(displayWidth),(displayHeight)); //Use instead if adjust to vertical;
  //offscreen.image(cImage, (-180)*1.5, (-50)*1.5, (displayWidth+180)*1.5, (displayHeight+50)*1.5); //Use instead if adjust to vertical
offscreen.endDraw();
 background(0);
   surface.render(offscreen);
  server.sendScreen();
  
}
  void mapping1(){
    // Draw the scene, offscreen
  offscreen.beginDraw();
 offscreen.background(0,174,240);
 offscreen.image( simpleOpenNI.depthImage(), 0, 0, width, height);
 offscreen.image(movie, 0, 0, width, height);
 //   offscreen.image(movie, -(width/2), 0, height*1.25, height); //Use instead if adjust to vertical
// offscreen.image(movies[currentMovie], -(width/2), 0, height*1.33, height);
offscreen.image(cImage,0,0,(displayWidth),(displayHeight)); //Use instead if adjust to vertical;
  //offscreen.image(cImage, (-180)*1.5, (-50)*1.5, (displayWidth+180)*1.5, (displayHeight+50)*1.5); //Use instead if adjust to vertical
offscreen.endDraw();
 background(0);
   surface.render(offscreen);
  server.sendScreen();
  
}
void keyPressed() {
  switch(key) {
  case 'c':
  //   enter/leave calibration mode, where surfaces can be warped 
//     and moved
    ks.toggleCalibration();
    break;
  case 'l':
//     loads the saved layout
   ks.load();
    break;
  case 's':
   // saves the layout
    ks.save();
    break;
}
}
boolean sketchFullScreen() {
  return true;
}
