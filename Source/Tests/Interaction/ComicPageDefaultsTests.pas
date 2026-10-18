unit ComicPageDefaultsTests;

// 責務：新規作品の投稿寸法、保存済み作品の寸法保持、組込みと任意サイズの選択を検証する。
interface
uses ComicTestSupport;
procedure RunPageDefaultsChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.JSON, System.IOUtils,
  System.Generics.Collections, Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics, Vcl.Imaging.pngimage,
  ComicModel, ComicPagePresets, ComicPageDialog, ComicRender;
procedure CheckNewProject(Host: TComicTestForm);
var Project,Reloaded: TComicProject; Renderer: TComicRenderer; PNG: TPngImage; Path: string; J: TJSONObject; Pair: TJSONPair;
begin
  Project:=TComicProject.Create; Reloaded:=TComicProject.Create; Renderer:=TComicRenderer.Create; PNG:=TPngImage.Create;
  try
    Host.Check((Project.Width=650) and (Project.Height=975) and Project.PageBasis.Valid,'new project model defaults to 650 x 975');
    Project.Initialize('ニコニコ漫画 初期サイズ fixture','1');
    Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
    Host.Check((Reloaded.Width=650) and (Reloaded.Height=975),'new project creation saves the 650 x 975 dimensions');
    Path:=TPath.Combine(Host.TestFolder,'default-page-size.png'); Renderer.ExportPage(Project,Project.Pages[0],Path); PNG.LoadFromFile(Path);
    Host.Check((PNG.Width=650) and (PNG.Height=975),'default PNG output uses exactly 650 x 975 pixels');
    Project.Width:=1200; Project.Height:=1700; Project.Save; Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
    Host.Check((Reloaded.Width=1200) and (Reloaded.Height=1700),'saved older project dimensions are preserved on loading');
    J:=Project.Json;
    try
      Pair:=J.RemovePair('width'); Pair.Free; Pair:=J.RemovePair('height'); Pair.Free; Reloaded.Restore(J.ToJSON);
      Host.Check((Reloaded.Width=1200) and (Reloaded.Height=1700),'old files without dimensions retain the previous format fallback');
    finally J.Free; end;
  finally PNG.Free; Renderer.Free; Reloaded.Free; Project.Free; end;
end;
procedure CheckPageChoices(Host: TComicTestForm);
var Presets,Loaded: TObjectList<TComicPagePreset>; Dialog: TComicPageDialog; Basis: TComicPageBasis;
  Preset: TComicPagePreset; I,PPI: Integer; Key: Word; Before,Path: string; Shot: Vcl.Graphics.TBitmap; PNG: TPngImage;
begin
  Presets:=TObjectList<TComicPagePreset>.Create; Loaded:=TObjectList<TComicPagePreset>.Create;
  Shot:=Vcl.Graphics.TBitmap.Create; PNG:=TPngImage.Create;
  try
    SeedPagePresets(Presets); Host.Check(Presets.Count=BuiltInPagePresetCount,'all built-in page size presets are available');
    Host.Check((Presets[0].Basis.Width=650) and (Presets[0].Basis.Height=975),'posting size is the first preset');
    Host.Check((Presets[1].ID='builtin-standard') and (Presets[1].Basis.Width=1200) and (Presets[1].Basis.Height=1700),
      'previous standard remains selectable with its stable preset identity');
    Host.Check((Presets[2].Basis.Width=1300) and (Presets[2].Basis.Height=1950),'twice the posting dimensions are available as a preset');
    Basis:=Presets[0].Basis; Path:=TPath.Combine(Host.TestFolder,'new-page-presets.json');
    Dialog:=TComicPageDialog.CreateSettings(Host,Basis,Presets,Path,True);
    try
      for I:=0 to Dialog.ComponentCount-1 do if Dialog.Components[I] is TComboBox then
        Host.Check(TComboBox(Dialog.Components[I]).ItemIndex=0,'page settings initially display the matching posting preset');
      for I:=0 to BuiltInPagePresetCount-1 do begin
        Dialog.SelectPreset(I); Key:=VK_RETURN; Dialog.KeyDown(Key,[]);
        Host.Check(Dialog.ResultBasis.Same(Presets[I].Basis),'accepting a built-in preset copies its complete size and margins');
        Dialog.ModalResult:=0;
      end;
      Basis.Width:=800; Basis.Height:=1200; Dialog.SetDraftBasis(Basis); Preset:=Dialog.RegisterPreset('任意 800 × 1200');
      SavePagePresets(Presets,Path); SeedPagePresets(Loaded); LoadPagePresets(Loaded,Path);
      Host.Check((Loaded.Count=BuiltInPagePresetCount+1) and (Loaded.Last.ID=Preset.ID) and Loaded.Last.Basis.Same(Basis),
        'custom page size survives save and reload alongside built-in choices');
      Dialog.SetDraftBasis(Presets[0].Basis); Dialog.RegisterPreset('同じ寸法の別名');
      Dialog.SelectPreset(Presets.Count-1);
      for I:=0 to Dialog.ComponentCount-1 do if Dialog.Components[I] is TComboBox then
        Host.Check(TComboBox(Dialog.Components[I]).ItemIndex=Presets.Count-1,
          'explicitly selecting a custom preset keeps its identity even when dimensions match a built-in');
      Dialog.SelectPreset(0); Before:=TFile.ReadAllText(Path); Key:=VK_ESCAPE; Dialog.KeyDown(Key,[]);
      Host.Check((Dialog.ModalResult=mrCancel) and (TFile.ReadAllText(Path)=Before),'canceling size selection does not modify the preset library');
      for PPI in [96,144] do begin
        Dialog.SelectPreset(0); Dialog.Scaled:=True; Dialog.ScaleForPPI(PPI); Dialog.Scaled:=False; Dialog.HandleNeeded;
        Shot.SetSize(Dialog.ClientWidth,Dialog.ClientHeight); Dialog.PaintTo(Shot.Canvas,0,0); PNG.Assign(Shot);
        PNG.SaveToFile(TPath.Combine(Host.TestFolder,'posting-page-preset-'+IntToStr(PPI)+'.png'));
      end;
    finally Dialog.Free; end;
  finally PNG.Free; Shot.Free; Loaded.Free; Presets.Free; end;
end;
procedure RunPageDefaultsChecks(Host: TComicTestForm);
begin CheckNewProject(Host); CheckPageChoices(Host); end;
end.
