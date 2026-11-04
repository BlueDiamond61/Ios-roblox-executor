using Microsoft.Win32;
using System.IO;
using System.Windows;
using System.Windows.Controls;

namespace MobileBloxStudio.Windows;

public partial class MainWindow : Window
{
    private readonly string _libraryPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
        "MobileBloxStudio",
        "Scripts");

    private string? _currentFile;
    private bool _loadingSelection;

    public MainWindow()
    {
        InitializeComponent();
        Directory.CreateDirectory(_libraryPath);
        RefreshLibrary();
        Log("Workspace loaded.");
        Log($"Script library: {_libraryPath}");
    }

    private void New_Click(object sender, RoutedEventArgs e)
    {
        Editor.Clear();
        FileNameBox.Text = "Untitled.lua";
        _currentFile = null;
        Log("New local script created.");
    }

    private void Open_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Title = "Open Lua or Luau file",
            Filter = "Lua files (*.lua)|*.lua|Luau files (*.luau)|*.luau|All files (*.*)|*.*",
            CheckFileExists = true
        };

        if (dialog.ShowDialog() != true)
            return;

        LoadFile(dialog.FileName);
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(_currentFile))
        {
            SaveAs_Click(sender, e);
            return;
        }

        SaveTo(_currentFile);
    }

    private void SaveAs_Click(object sender, RoutedEventArgs e)
    {
        var suggestedName = string.IsNullOrWhiteSpace(FileNameBox.Text)
            ? "Untitled.lua"
            : FileNameBox.Text.Trim();

        var dialog = new SaveFileDialog
        {
            Title = "Save script",
            Filter = "Lua files (*.lua)|*.lua|Luau files (*.luau)|*.luau|All files (*.*)|*.*",
            FileName = suggestedName,
            InitialDirectory = _libraryPath,
            DefaultExt = ".lua",
            AddExtension = true
        };

        if (dialog.ShowDialog() != true)
            return;

        SaveTo(dialog.FileName);
    }

    private void SaveTo(string path)
    {
        try
        {
            File.WriteAllText(path, Editor.Text);
            _currentFile = path;
            FileNameBox.Text = Path.GetFileName(path);
            RefreshLibrary();
            Log($"Saved: {path}");
        }
        catch (Exception ex)
        {
            Log($"Save failed: {ex.Message}");
            MessageBox.Show(this, ex.Message, "Could not save file",
                MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void LoadFile(string path)
    {
        try
        {
            Editor.Text = File.ReadAllText(path);
            _currentFile = path;
            FileNameBox.Text = Path.GetFileName(path);
            Log($"Opened: {path}");
        }
        catch (Exception ex)
        {
            Log($"Open failed: {ex.Message}");
            MessageBox.Show(this, ex.Message, "Could not open file",
                MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void Clear_Click(object sender, RoutedEventArgs e)
    {
        Editor.Clear();
        Log("Editor cleared.");
    }

    private void Preview_Click(object sender, RoutedEventArgs e)
    {
        var lines = string.IsNullOrEmpty(Editor.Text)
            ? 0
            : Editor.Text.Replace("\r\n", "\n").Split('\n').Length;
        var characters = Editor.Text.Length;

        Log($"Source preview: {lines} lines, {characters} characters.");
        Log("This build is an editor and file manager; it does not execute code in Roblox.");
    }

    private void RefreshLibrary_Click(object sender, RoutedEventArgs e)
    {
        RefreshLibrary();
        Log("Script library refreshed.");
    }

    private void RefreshLibrary()
    {
        Directory.CreateDirectory(_libraryPath);
        _loadingSelection = true;
        ScriptList.ItemsSource = Directory.EnumerateFiles(_libraryPath)
            .Where(path => Path.GetExtension(path).Equals(".lua", StringComparison.OrdinalIgnoreCase)
                        || Path.GetExtension(path).Equals(".luau", StringComparison.OrdinalIgnoreCase))
            .OrderBy(Path.GetFileName)
            .ToList();
        ScriptList.DisplayMemberPath = null;
        _loadingSelection = false;
    }

    private void ScriptList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_loadingSelection || ScriptList.SelectedItem is not string path)
            return;

        LoadFile(path);
        ScriptList.SelectedItem = null;
    }

    private void Log(string message)
    {
        ConsoleBox.AppendText($"{Environment.NewLine}> {message}");
        ConsoleBox.ScrollToEnd();
    }
}
