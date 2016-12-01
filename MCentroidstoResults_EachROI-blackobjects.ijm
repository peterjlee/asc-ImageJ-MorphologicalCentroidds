/* 	Based on "MCentroids.txt" Morphological centroids by thinning assumes black particles on white background: G.Landini
	http://www.mecourse.com/landinig/software/software.html
	Modified to add coordinates to Results Table: Peter J. Lee NHMFL
	Erode Each ROI individually version: 10/02/2016
*/
macro "Add morphological centroid coordinates to Results Table" {
	saveSettings();
	run("Options...", "iterations=1 white count=1"); /* set white background */
	setOption("BlackBackground", false);
	run("Colors...", "foreground=black background=white selection=yellow"); //set colors
	run("Appearance...", " "); /* do not use Inverting LUT */
	workingTitle = getTitle();
	if (checkForPlugin("morphology_collection")==0) restoreExit("Exiting: Gabriel Landini's morphology suite is needed to run this macro.");
	binaryCheck(workingTitle);
	checkForRoiManager();
	roiOriginalCount = roiManager("count");
	setBatchMode(true); //batch mode on
	start = getTime();
	getPixelSize(selectedUnit, pixelWidth, pixelHeight);
	lcf=(pixelWidth+pixelHeight)/2;
	objects = roiManager("count");
	mcImageWidth = getWidth();
	mcImageHeight = getHeight();
	showStatus("Looping through all " + roiOriginalCount + " objects for morphological centers . . .");
	for (i=0 ; i<roiOriginalCount; i++) {
		showProgress(-i, roiManager("count"));
		selectWindow(workingTitle);
		roiManager("select", i);
		Roi.getBounds(Rx, Ry, Rwidth, Rheight);
		setResult("ROIctr_X\(px\)", i, round(Rx + Rwidth/2));
		setResult("ROIctr_Y\(px\)", i, round(Ry + Rheight/2));
		Roi.getContainedPoints(RPx, RPy); // this includes holes when ROIs are used so no hole filling is needed
		newImage("Contained Points "+i,"8-bit black",Rwidth,Rheight,1); // give each sub-image a unique name for debugging purposes
		for (j=0; j<RPx.length; j++)
			setPixel(RPx[j]-Rx, RPy[j]-Ry, 255);
		selectWindow("Contained Points "+i);
		run("BinaryThin2 ", "kernel_a='0 2 2 0 1 1 0 0 2 ' kernel_b='0 0 2 0 1 1 0 2 2 ' rotations='rotate 45' iterations=-1 white");
		if (lcf==1) {
			for (RPx=1; RPx<(Rwidth-1); RPx++){
				for (RPy=1; RPy<(Rheight-1); RPy++){ // start at "1" because there should not be a pixel at the border
					if((getPixel(RPx, RPy))==255) {  
						setResult("mc_X\(px\)", i, RPx+Rx);
						setResult("mc_Y\(px\)", i, RPy+Ry);
						setResult("mc_offsetX\(px\)", i, getResult("X",i)-(RPx+Rx));
						setResult("mc_offsetY\(px\)", i, getResult("Y",i)-(RPy+Ry));
						RPy = Rheight;
						RPx = Rwidth; // one point and done
					}
				}
			}
		}
		else if (lcf!=1) {
			for (RPx=1; RPx<(Rwidth-1); RPx++){
				for (RPy=1; RPy<(Rheight-1); RPy++){ // start at "1" because there should not be a pixel at the border
					if((getPixel(RPx, RPy))==255) {
						setResult("mc_X\(px\)", i, RPx+Rx);
						setResult("mc_Y\(px\)", i, RPy+Ry);					
						// setResult("mc_X\(" + selectedUnit + "\)", i, (RPx+Rx)*lcf); //perhaps not too useful
						// setResult("mc_Y\(" + selectedUnit + "\)", i, (RPy+Ry)*lcf); //
						setResult("mc_offsetX\(px\)", i, round((getResult("X",i)/lcf-(RPx+Rx))));
						setResult("mc_offsetY\(px\)", i, round((getResult("Y",i)/lcf-(RPy+Ry))));
						RPy = Rheight;
						RPx = Rwidth; // one point and done
					}
				}
			}
		}
		closeImageByTitle("Contained Points "+i);
	}
	updateResults();
	run("Select None");
	setBatchMode("exit & display"); /* exit batch mode */
	restoreSettings();
	showStatus("Macro Finished: " + roiManager("count") + " objects analyzed in " + (getTime()-start)/1000 + "s.");
	beep(); wait(300); beep(); wait(300); beep();
}
/*-----------------functions---------------------*/

	function closeImageByTitle(windowTitle) {  /* cannot be used with tables */
        if (isOpen(windowTitle)) {
		selectWindow(windowTitle);
        close();
		}
	}
	function checkForRoiManager() {
		if (roiManager("count")==0)  {
			Dialog.create("No ROI");
			Dialog.addCheckbox("Run Analyze-particles to generate roiManager values?", true);
			Dialog.addMessage("This macro requires that all objects have been loaded into the roi manager.");
			Dialog.show();
			analyzeNow = Dialog.getCheckbox(); //if (analyzeNow==true) ImageJ analyze particles will be performed, otherwise exit;
			if (analyzeNow==true) {
				setOption("BlackBackground", false);
				run("Analyze Particles...", "display clear add");
			}
			else restoreExit();
		}
	}
	function binaryCheck(windowTitle) { // for white objects on black background
		selectWindow(windowTitle);
		if (is("binary")==0) run("8-bit");
		// Quick-n-dirty threshold if not previously thresholded
		getThreshold(t1,t2); 
		if (t1==-1)  {
			run("8-bit");
			setThreshold(0, 128);
			setOption("BlackBackground", true);
			run("Convert to Mask");
			run("Invert");
			}
		// Make sure black objects on white background for consistency	
		if (((getPixel(0, 0))==0 || (getPixel(0, 1))==0 || (getPixel(1, 0))==0 || (getPixel(1, 1))==0))
			run("Invert"); 
		// Sometimes the outline procedure will leave a pixel border around the outside - this next step checks for this.
		// i.e. the corner 4 pixels should now be all black, if not, we have a "border issue".
		if (((getPixel(0, 0))+(getPixel(0, 1))+(getPixel(1, 0))+(getPixel(1, 1))) != 4*(getPixel(0, 0)) ) 
				restoreExit("Border Issue"); 	
	}
	function checkForPlugin(pluginName) {
		var pluginCheck = 0, subFolderCount = 0;
		if (getDirectory("plugins") == "") restoreExit("Failure to find any plugins!");
		else pluginDir = getDirectory("plugins");
		if (!endsWith(pluginName, ".jar")) pluginName = pluginName + ".jar";
		if (File.exists(pluginDir + pluginName)) {
				pluginCheck = 1;
				showStatus(pluginName + "found in: "  + pluginDir);
		}
		else {
			pluginList = getFileList(pluginDir);
			subFolderList = newArray(pluginList.length);
			for (i=0; i<pluginList.length; i++) {
				if (endsWith(pluginList[i], "/")) {
					subFolderList[subFolderCount] = pluginList[i];
					subFolderCount = subFolderCount +1;
				}
			}
			subFolderList = Array.slice(subFolderList, 0, subFolderCount);
			for (i=0; i<subFolderList.length; i++) {
				if (File.exists(pluginDir + subFolderList[i] +  "\\" + pluginName)) {
					pluginCheck = 1;
					showStatus(pluginName + " found in: " + pluginDir + subFolderList[i]);
					i = subFolderList.length;
				}
			}
		}
		return pluginCheck;
	}
		function restoreExit(message){ // clean up before aborting macro then exit
		restoreSettings(); //clean up before exiting
		setBatchMode("exit & display"); // not sure if this does anything useful if exiting gracefully but otherwise harmless
		exit(message);
	}