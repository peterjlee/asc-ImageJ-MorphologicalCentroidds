/* 	Based on "MCentroids.txt" Morphological centroids by thinning assumes white particles: G.Landini
	http://imagejdocu.tudor.lu/doku.php?id=plugin:morphology:morphological_operators_for_imagej:start
	http://www.mecourse.com/landinig/software/software.html
	Modified to add coordinates to Results Table: Peter J. Lee NHMFL  7/20-29/2016
	This version v161011 updated v180102 for functions
*/
macro "Add morphological centroid coordinates to Results Table" {
	saveSettings();
	run("Options...", "iterations=1 white count=1"); /* set white background */
	run("Colors...", "foreground=black background=white selection=yellow"); //set colors
	run("Appearance...", " "); /* do not use Inverting LUT */
	workingTitle = getTitle();
	if (checkForPlugin("morphology_collection")==0) restoreExit("Exiting: Gabriel Landini's morphology suite is needed to run this macro.");
	binaryCheck(workingTitle);
	checkForRoiManager();
	setBatchMode(true); //batch mode on
	start = getTime();
	objects = roiManager("count");
	mcImageWidth = getWidth();
	mcImageHeight = getHeight();
	
	// create MCentroids image
	selectWindow(workingTitle);
	run("Duplicate...", "title=MCentroids");
	if (mcImageWidth>=10000 && mcImageHeight>=10000) {
		sf = 25; // scaling factor in %
		run("Options...", "iterations=2 count=1 black do=Nothing");
		run("Erode"); // to keep objects separated after scaling
		run("Scale...", "x="+sf/100+" y="+sf/100+" interpolation=None create title=scaled");
		closeImageByTitle("MCentroids");
		selectWindow("scaled");
		mcScaledImageWidth = getWidth();
		mcScaledImageHeight = getHeight();
		print("The image is very large and was be scaled to "+sf+"\% \("+mcScaledImageWidth+" x " +mcScaledImageHeight+ "\) for faster erosion");
		run("Fill Holes");
		run("BinaryThin2 ", "kernel_a='0 2 2 0 1 1 0 0 2 ' kernel_b='0 0 2 0 1 1 0 2 2 ' rotations='rotate 45' iterations=-1 black");
		// add mcentroids to x and Y arrays
		mcXpoints = newArray(mcScaledImageWidth * mcScaledImageHeight);
		mcYpoints = newArray(mcScaledImageWidth * mcScaledImageHeight);
		mcCounter = 0;
		for (x=0; x<mcScaledImageWidth; x++){
			showProgress(x, mcScaledImageWidth);
			for (y=0; y<mcScaledImageHeight; y++){
				if((getPixel(x, y))!=0) {  //previously determined the background is zero
						mcXpoints[mcCounter] = x * 100/sf;
						mcYpoints[mcCounter] = y * 100/sf;
						mcCounter += 1;
				}
			}
		}
		closeImageByTitle("scaled");
	}
	else {
		run("Duplicate...", "title=MCentroids");
		run("Fill Holes");
		run("BinaryThin2 ", "kernel_a='0 2 2 0 1 1 0 0 2 ' kernel_b='0 0 2 0 1 1 0 2 2 ' rotations='rotate 45' iterations=-1 black");
		// add mcentroids to x and Y arrays
		mcXpoints = newArray(mcImageWidth * mcImageHeight);
		mcYpoints = newArray(mcImageWidth * mcImageHeight);
		mcCounter = 0;
		for (x=0; x<mcImageWidth; x++){
			showProgress(x, mcImageWidth);
			for (y=0; y<mcImageHeight; y++){
				if((getPixel(x, y))!=0) {  //previously determined the background is zero
						mcXpoints[mcCounter] = x;
						mcYpoints[mcCounter] = y;
						mcCounter += 1;
				}
			}
		}
	}
	mcXpoints = Array.slice(mcXpoints, 0, mcCounter);
	mcYpoints = Array.slice(mcYpoints, 0, mcCounter);
	if (mcCounter!=objects) print("Warning: " + mcCounter + " Morphological Centers BUT " + objects + " ROI objects; macro will add only first value");
	closeImageByTitle("MCentroids");
	// create labeling image if one is not open
	selectWindow(workingTitle);
	if (!isOpen("Labeled")) {
		newImage("Labeled", "32-bit black", mcImageWidth, mcImageHeight, 1);
		for (i=0 ; i<objects; i++) {
			roiManager("select", i);
			setColor(1+i);
			fill(); /* This only only works for 32-bit images so hopefully it is not a bug */
		}
	}
	selectWindow("Labeled"); // do this loop separately so you do not have to switch between windows within the loop
	for (i=0 ; i<objects; i++) {
		showStatus("Looping over object " + i + ", " + (objects-i) + " more to go");
		labelI = i+1;
		for (u=0; u<mcCounter; u++){
			if (getPixel(mcXpoints[u], mcYpoints[u])==labelI) {  //check by intensity label
				setResult("mc_X\(px\)", i, mcXpoints[u]);
				setResult("mc_Y\(px\)", i, mcYpoints[u]);
				u = mcCounter;	
			}
		}
	}
	updateResults();
	run("Select None");
	// closeImageByTitle("Result of Labeled");
	closeImageByTitle("Labeled");
	closeImageByTitle("MCentroids");
	setBatchMode("exit & display"); /* exit batch mode */
	restoreSettings();
	showStatus("Macro Finished: " + roiManager("count") + " objects analyzed in " + (getTime()-start)/1000 + "s.");
	beep(); wait(500); beep(); wait(100); beep();
}
	/* ( 8(|)   ( 8(|)  Functions  ( 8(|)  ( 8(|)   */
	
	function binaryCheck(windowTitle) { /* for black objects on white background */
		selectWindow(windowTitle);
		if (is("binary")==0) run("8-bit");
		/* Quick-n-dirty threshold if not previously thresholded */
		getThreshold(t1,t2); 
		if (t1==-1)  {
			run("8-bit");
			setThreshold(0, 128);
			setOption("BlackBackground", true);
			run("Convert to Mask");
			run("Invert");
			}
		/* Make sure black objects on white background for consistency */
		if (((getPixel(0, 0))==0 || (getPixel(0, 1))==0 || (getPixel(1, 0))==0 || (getPixel(1, 1))==0))
			run("Invert"); 
		/*	Sometimes the outline procedure will leave a pixel border around the outside - this next step checks for this.
			i.e. the corner 4 pixels should now be all black, if not, we have a "border issue". */
		if (((getPixel(0, 0))+(getPixel(0, 1))+(getPixel(1, 0))+(getPixel(1, 1))) != 4*(getPixel(0, 0)) ) 
				restoreExit("Border Issue"); 	
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
					pluginCheck = true;
					showStatus(pluginName + " found in: " + pluginDir + subFolderList[i]);
					i = subFolderList.length;
				}
			}
		}
		return pluginCheck;
	}
	function checkForRoiManager() {
		/* v161109 adds the return of the updated ROI count and also adds dialog if there are already entries just in case . . */
		nROIs = roiManager("count");
		nRES = nResults; /* not really needed except to provide useful information below */
		if (nROIs==0) runAnalyze = true;
		else runAnalyze = getBoolean("There are already " + nROIs + " in the ROI manager; do you want to clear the ROI manager and reanalyze?");
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