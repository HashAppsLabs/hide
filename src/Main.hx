import component.*;
import core.FileAccess;
import core.FileDialog;
import core.ProjectAccess;
import core.TabsManager;
import haxe.ds.StringMap.StringMap;
import haxe.Json;
import haxe.Timer;
import jQuery.*;
import js.Browser;
import js.html.KeyboardEvent;
import js.html.WheelEvent;
import js.Lib;
import ui.menu.basic.Menu;
import ui.menu.DeveloperToolsMenu;
import ui.menu.EditMenu;
import ui.menu.FileMenu;
import ui.menu.HelpMenu;
import ui.menu.RunMenu;
import ui.menu.SourceMenu;
import ui.menu.ViewMenu;
import ui.NewProjectDialog;

class Main {

	static public var session:Session;
	static public var settings:StringMap<String>;
	static private var menus:StringMap<Menu>;	
	
	// the program starts here	
    static public function main():Void 
	{	
		new JQuery(function():Void
			{	
				init();
			});
    }

    static public function close():Void 
	{
    	Sys.exit(0);
    }
    
	// the editor will always run this first. 
    static function init():Void
    {
		Browser.window.onresize = function (e)
		{
			resize();
		}
				
		TabsManager.init();
		
		initDragAndDropListeners();
		initHotKeys();
		initMouseZoom();
		
		// var session are used for storing vital information regarding the current usage
		session = new Session();
		
		// var settings are predefined variables for the IDE.
		settings = new StringMap();
		
		FileDialog.init();		
		
		FileTree.init();
		
		Layout.init();
		
		initCorePlugin();
		
		PreserveWindowState.init();
		
		CompletionServer.init();
		CompletionClient.init();
		
		NewProjectDialog.init();
    }
	
	static private function initMouseZoom():Void
	{
		Browser.document.onmousewheel = function(e:WheelEvent)
		{
			if (e.altKey)
			{
				if (e.wheelDeltaY < 0)
				{
					var font_size:Int = Std.parseInt(new JQuery(".CodeMirror").css("font-size"));
					font_size--;
					setFontSize(font_size);
					e.preventDefault(); 
					e.stopPropagation(); 
				}
				else if (e.wheelDeltaY > 0)
				{
					var font_size:Int = Std.parseInt(new JQuery(".CodeMirror").css("font-size"));
					font_size++;
					setFontSize(font_size);
					e.preventDefault(); 
					e.stopPropagation(); 
				}
			}
		};
	}
	
	static private function initHotKeys():Void
	{
		Browser.window.addEventListener("keyup", function (e:KeyboardEvent)
		{
			if (e.ctrlKey)
			{
				if (!e.shiftKey)
				{
					switch (e.keyCode) 
					{
						//Ctrl-W
						case 87:
							TabsManager.closeActiveTab();
						//Ctrl-0
						case 48:
							new JQuery(".CodeMirror").css("font-size", "8pt");
							new JQuery(".CodeMirror-hint").css("font-size", "8t");
							new JQuery(".CodeMirror-hints").css("font-size", Std.string(8*0.9) +"pt");
						//Ctrl-'-'
						case 189:
							var font_size:Int = Std.parseInt(new JQuery(".CodeMirror").css("font-size"));
							font_size--;
							setFontSize(font_size);
						//Ctrl-'+'
						case 187:
							var font_size:Int = Std.parseInt(new JQuery(".CodeMirror").css("font-size"));
							font_size++;
							setFontSize(font_size);
						//Ctrl-Tab
						case 9:
							TabsManager.showNextTab();
							e.preventDefault(); 
							e.stopPropagation(); 
						//Ctrl-O
						case 79:
							FileAccess.openFile();
						//Ctrl-S
						case 83:
							FileAccess.saveActiveFile();
						case 'N'.code:
							FileAccess.createNewFile();
						default:
							
					}			
				}
				else
				{
					switch (e.keyCode) 
					{
						//Ctrl-Shift-0
						case 48:
							Utils.window.zoomLevel = 0;
						//Ctrl-Shift-'-'
						case 189:
							Utils.zoomOut();
						//Ctrl-Shift-'+'
						case 187:
							Utils.zoomIn();
						//Ctrl-Shift-Tab
						case 9:
							TabsManager.showPreviousTab();
							e.preventDefault(); 
							e.stopPropagation(); 
						//Ctrl-Shift-O
						case 79:
							ProjectAccess.openProject();
						//Ctrl-Shift-S
						case 83:
							FileAccess.saveActiveFileAs();
						//Ctrl-Shift-T
						case 'T'.code:
							TabsManager.applyRandomTheme();
						case 'N'.code:
							ProjectAccess.createNewProject();
						case 'R'.code:
							Utils.window.reloadIgnoringCache();
						default:
							
					}		
				}
			}
			else
			{
				if (e.keyCode == 13 && e.shiftKey && e.altKey)
				{
					Utils.toggleFullscreen();
				}
				//F5
				else if (e.keyCode == 116)
				{
					if (ProjectAccess.currentProject != null)
					{
						BuildTools.runProject();
					}
				}
				//F8
				else if (e.keyCode == 119) 
				{
					if (ProjectAccess.currentProject != null)
					{
						BuildTools.buildProject();
					}
				}
			}
		});
	}
    
	private static function initDragAndDropListeners():Void
	{
		Browser.window.ondragover = function(e) { e.preventDefault(); e.stopPropagation(); return false; };
		Browser.window.ondrop = function(e:Dynamic) 
		{
			e.preventDefault();
			e.stopPropagation();

			for (i in 0...e.dataTransfer.files.length) 
			{
				TabsManager.openFileInNewTab(e.dataTransfer.files[i].path);
			}

			return false;
		};
	}
    
	public static function resize():Void
	{		
		if (TabsManager.editor != null)
		{
			TabsManager.editor.refresh();
		}
	}
	
	static function setFontSize(font_size:Int):Void
	{
		new JQuery(".CodeMirror").css("font-size", Std.string(font_size) + "px");
		new JQuery(".CodeMirror-hint").css("font-size", Std.string(font_size - 2) + "px");
		new JQuery(".CodeMirror-hints").css("font-size", Std.string(font_size - 2) + "px");
	}
	
    static function initCorePlugin():Void
    {
		initMenu();
    }
	
	private static function initMenu():Void
	{
		menus = new StringMap();
		
		menus.set("file", new FileMenu());
		menus.set("edit", new EditMenu());
		menus.set("view", new ViewMenu());
		menus.set("source", new SourceMenu());
		menus.set("run", new RunMenu());
		menus.set("help", new HelpMenu());
		menus.set("developertools", new DeveloperToolsMenu());
		
		Timer.delay(updateMenu, 100);
		Timer.delay(updateMenu, 10000);
	}
	
	public static function updateMenu():Void
	{
		var fileMenuDisabledItems:Array<String> = new Array();
		
		if (TabsManager.docs.length == 0)
		{
			fileMenuDisabledItems.push("Close File");
			fileMenuDisabledItems.push("Save");
			fileMenuDisabledItems.push("Save as...");
			fileMenuDisabledItems.push("Save all");
			
			menus.get("edit").setMenuEnabled(false);
		}
		else
		{
			menus.get("edit").setMenuEnabled(true);
		}
		
		if (ProjectAccess.currentProject == null)
		{
			fileMenuDisabledItems.push("Close Project...");
			fileMenuDisabledItems.push("Project Properties");
			
			menus.get("run").setMenuEnabled(false);
		}
		else
		{
			menus.get("run").setMenuEnabled(true);
		}
		
		menus.get("file").setDisabled(fileMenuDisabledItems);
	}
    
}
