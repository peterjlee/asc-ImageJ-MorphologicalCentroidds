/* 	Based on "MCentroids.txt" Morphological centroids by thinning assumes white particles: G.Landini
	http://imagejdocu.tudor.lu/doku.php?id=plugin:morphology:morphological_operators_for_imagej:start
	http://www.mecourse.com/landinig/software/software.html
	Modified to add coordinates to Results Table: Peter J. Lee NHMFL  7/20-29/2016
	v180102	fixed typos and updated functions.
	v180104 removed unnecessary changes to settings.
	v180312 Add minimum and maximum morphological radii.
*/
macro "Add morphological centroid coordinates to Results Table" {  
	workingTitle = getTitle();
	if (!checkForPlugin("morphology_collection")) restoreExit("Exiting: Gabriel Landini's morphology suite is needed to run this macro.");
	binaryCheck(workingTitle); /* Makes sure image is binary and sets to white background, black objects */
	checkForRoiManager(); /* This macro uses ROIs and a Results table that matches in count */
	roiOriginalCount = roiManager("count");
	addRadii = getBoolean("Do you also want to add the min and max M-Centroid radii to the Results table?");
	setBatchMode(true); /* batch mode on */
	start = getTime();
	getPixelSize(unit, pixelWidth, pixelHeight);
	lcf=(pixelWidth+pixelHeight)/2;
	objects = roiManager("count");
	mcImageWidth = getWidth();
	mcImageHeight = getHeight();
	showStatus("Looping through all " + roiOriginalCount + " objects for morphological centers . . .");
	for (i=0 ; i<roiOriginalCount; i++) {
		showProgress(-i, roiManager("count"));
		selectWindow(workingTitle);
		roiManager("select", i);
		if(addRadii) run("Interpolate", "interval=1");	getSelectionCoordinates(xPoints, yPoints); /* place border coordinates in array for radius measurements - Wayne Rasband: http://imagej.1557.x6.nabble.com/List-all-pixel-coordinates-in-ROI-td3705127.html */
		Roi.getBounds(Rx, Ry, Rwidth, Rheight);
		setResult("ROIctr_X\(px\)", i, Rx + Rwidth/2);
		setResult("ROIctr_Y\(px\)", i, Ry + Rheight/2);
		Roi.getContainedPoints(RPx, RPy); /* this includes holes when ROIs are used so no hole filling is needed */
		newImage("Contained Points","8-bit black",Rwidth,Rheight,1); /* give each sub-image a unique name for debugging purposes */
		for (j=0; j<lengthOf(RPx); j++)
			setPixel(RPx[j]-Rx, RPy[j]-Ry, 255);
		selectWindow("Contained Points");
		run("BinaryThin2 ", "kernel_a='0 2 2 0 1 1 0 0 2 ' kernel_b='0 0 2 0 1 1 0 2 2 ' rotations='rotate 45' iterations=-1 white");
		for (j=0; j<lengthOf(RPx); j++){
			if((getPixel(RPx[j]-Rx, RPy[j]-Ry))==255) {
				centroidX = RPx[j]; centroidY = RPy[j];
				setResult("mc_X\(px\)", i, centroidX);
				setResult("mc_Y\(px\)", i, centroidY);
				setResult("mc_offsetX\(px\)", i, getResult("X",i)/lcf-(centroidX));
				setResult("mc_offsetY\(px\)", i, getResult("Y",i)/lcf-(centroidY));
				// if (lcf!=1) {
					// setResult("mc_X\(" + unit + "\)", i, (centroidX)*lcf); /* perhaps not too useful */
					// setResult("mc_Y\(" + unit + "\)", i, (centroidY)*lcf); /* perhaps not too useful */	
				// }
				j = lengthOf(RPx); /* one point and done */
			}
		}
		closeImageByTitle("Contained Points");
		if(addRadii) {
			/* Now measure min and max radii from M-Centroid */
			rMin = Rwidth + Rheight; rMax = 0;
			for (j=0 ; j<(lengthOf(xPoints)); j++) {
				dist = sqrt((centroidX-xPoints[j])*(centroidX-xPoints[j])+(centroidY-yPoints[j])*(centroidY-yPoints[j]));
				if (dist < rMin) { rMin = dist; rMinX = xPoints[j]; rMinY = yPoints[j];}
				if (dist > rMax) { rMax = dist; rMaxX = xPoints[j]; rMaxY = yPoints[j];}
			}
			if (rMin == 0) rMin = 0.5; /* Correct for 1 pixel width objects and interpolate error */
			setResult("mc_minRadX", i, rMinX);
			setResult("mc_minRadY", i, rMinY);
			setResult("mc_maxRadX", i, rMaxX);
			setResult("mc_maxRadY", i, rMaxY);
			setResult("mc_minRad\(px\)", i, rMin);
			setResult("mc_maxRad\(px\)", i, rMax);
			setResult("mc_AR", i, rMax/rMin);
			if (lcf!=1) {
				setResult('mc_minRad' + "\(" + unit + "\)", i, rMin*lcf);
				setResult('mc_maxRad' + "\(" + unit + "\)", i, rMax*lcf);
			}
		}
	}
	updateResults();
	run("Select None");
	setBatchMode("exit & display"); /* exit batch mode */
	showStatus("MC Function Finished: " + roiManager("count") + " objects analyzed in " + (getTime()-start)/1000 + "s.");
	beep(); wait(300); beep(); wait(300); beep();
	run("Collect Garbage"); 
}
	/*
		   ( 8(|)	( 8(|)	Functions	@@@@@:-)	@@@@@:-)
   */
	function binaryCheck(windowTitle) { /* for black objects on white background */
		/* v180104 added line to remove inverting LUT and changed to auto default threshold */
		selectWindow(windowTitle);
		if (is("binary")==0) run("8-bit");
		/* Quick-n-dirty threshold if not previously thresholded */
		getThreshold(t1,t2); 
		if (t1==-1)  {
			run("8-bit");
			run("Auto Threshold", "method=Default");
			run("Convert to Mask");
			}
		/* Make sure black objects on white background for consistency */
		if (((getPixel(0, 0))==0 || (getPixel(0, 1))==0 || (getPixel(1, 0))==0 || (getPixel(1, 1))==0))
			run("Invert"); 
		/*	Sometimes the outline procedure will leave a pixel border around the outside - this next step checks for this.
			i.e. the corner 4 pixels should now be all black, if not, we have a "border issue". */
		if (((getPixel(0, 0))+(getPixel(0, 1))+(getPixel(1, 0))+(getPixel(1, 1))) != 4*(getPixel(0, 0)) ) 
				restoreExit("Border Issue"); 	
		if (is("Inverting LUT")==true) run("Invert LUT");
	}
	function checkForRoiManager() {
		/* v161109 adds the return of the updated ROI count and also adds dialog if there are already entries just in case . .
			v180104 only asks about ROIs if there is a mismatch with the results */
		nROIs = roiManager("count");
		nRES = nResults; /* Used to check for ROIs:Results mismatch */
		if(nROIs==0) runAnalyze = true; /* Assumes that ROIs are required and that is why this function is being called */
		else if(nROIs!=nRES) runAnalyze = getBoolean("There are " + nRES + " results and " + nROIs + " ROIs; do you want to clear the ROI manager and reanalyze?");
		else runAnalyze = false;
		if (runAnalyze) {
			roiManager("reset");
			Dialog.create("Analysis check");
			Dialog.addCheckbox("Run Analyze-particles to generate new roiManager values?", true);
			Dialog.addMessage("This macro requires that all objects have been loaded into the roi manager.\n \nThere are   " + nRES +"   results.\nThere are   " + nROIs +"   ROIs.");
			Dialog.show();
			analyzeNow = Dialog.getCheckbox();
			if (analyzeNow) {
				setOption("BlackBackground", false);
				if (nResults==0)
					run("Analyze Particles...", "display add");
				else run("Analyze Particles..."); /* let user select settings */
				if (nResults!=roiManager("count"))
					restoreExit("Results and ROI Manager counts do not match!");
			}
			else restoreExit("Goodbye, your previous setting will be restored.");
		}
		return roiManager("count"); /* returns the new count of entries */
	}
	function checkForPlugin(pluginName) {
		/* v161102 changed to true-false */
		var pluginCheck = false, subFolderCount = 0;
		if (getDirectory("plugins") == "") restoreExit("Failure to find any plugins!");
		else pluginDir = getDirectory("plugins");
		if (!endsWith(pluginName, ".jar")) pluginName = pluginName + ".jar";
		if (File.exists(pluginDir + pluginName)) {
				pluginCheck = true;
				showStatus(pluginName + "found in: "  + pluginDir);
		}
		else {
			pluginList = getFileList(pluginDir);
			subFolderList = newArray(lengthOf(pluginList));
			for (i=0; i<lengthOf(pluginList); i++) {
				if (endsWith(pluginList[i], "/")) {
					subFolderList[subFolderCount] = pluginList[i];
					subFolderCount = subFolderCount +1;
				}
			}
			subFolderList = Array.slice(subFolderList, 0, subFolderCount);
			for (i=0; i<lengthOf(subFolderList); i++) {
				if (File.exists(pluginDir + subFolderList[i] +  "\\" + pluginName)) {
					pluginCheck = true;
					showStatus(pluginName + " found in: " + pluginDir + subFolderList[i]);
					i = lengthOf(subFolderList);
				}
			}
		}
		return pluginCheck;
	}
	function closeImageByTitle(windowTitle) {  /* cannot be used with tables */
		if (isOpen(windowTitle)) {
		selectWindow(windowTitle);
		close();
		}
	}
	function restoreExit(message){ /* clean up before aborting macro then exit */
		/* 9/9/2017 added Garbage clean up suggested by Luc LaLonde - LBNL */
		restoreSettings(); /* clean up before exiting */
		setBatchMode("exit & display"); /* not sure if this does anything useful if exiting gracefully but otherwise harmless */
		run("Collect Garbage");
		exit(message);
	}