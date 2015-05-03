{******************************************************************************}
{* SAS.Planet (SAS.�������)                                                   *}
{* Copyright (C) 2007-2014, SAS.Planet development team.                      *}
{* This program is free software: you can redistribute it and/or modify       *}
{* it under the terms of the GNU General Public License as published by       *}
{* the Free Software Foundation, either version 3 of the License, or          *}
{* (at your option) any later version.                                        *}
{*                                                                            *}
{* This program is distributed in the hope that it will be useful,            *}
{* but WITHOUT ANY WARRANTY; without even the implied warranty of             *}
{* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *}
{* GNU General Public License for more details.                               *}
{*                                                                            *}
{* You should have received a copy of the GNU General Public License          *}
{* along with this program.  If not, see <http://www.gnu.org/licenses/>.      *}
{*                                                                            *}
{* http://sasgis.org                                                          *}
{* info@sasgis.org                                                            *}
{******************************************************************************}

unit fr_MergePolygons;

interface

uses
  SysUtils,
  Classes,
  Controls,
  Forms,
  ComCtrls,
  Dialogs,
  TBX,
  TBXExtItems,
  TB2Item,
  TB2ExtItems,
  TB2Dock,
  TB2Toolbar,
  i_NotifierOperation,
  i_MapViewGoto,
  i_GeometryLonLat,
  i_GeometryLonLatFactory,
  i_VectorDataFactory,
  i_VectorDataItemSimple,
  t_MergePolygonsProcessor,
  u_MergePolygonsProcessor;

type
  TfrMergePolygons = class(TFrame)
    tvPolygonsList: TTreeView;
    tbTop: TTBXToolbar;
    tbxOperation: TTBXComboBoxItem;
    tbxMerge: TTBXItem;
    tbxSep1: TTBXSeparatorItem;
    tbxUp: TTBXItem;
    tbxDown: TTBXItem;
    tbxSep2: TTBXSeparatorItem;
    tbxDel: TTBXItem;
    procedure tvPolygonsListAddition(Sender: TObject; Node: TTreeNode);
    procedure tbxMergeClick(Sender: TObject);
    procedure tbxUpClick(Sender: TObject);
    procedure tbxDownClick(Sender: TObject);
    procedure tbxDelClick(Sender: TObject);
    procedure tvPolygonsListDblClick(Sender: TObject);
  private
    FMapGoto: IMapViewGoto;
    FItems: TMergePolygonsItemArray;
    FMergeProcessor: TMergePolygonsProcessor;
    procedure RebuildTree;
    function IsDublicate(const AItem: TMergePolygonsItem): Boolean;
    procedure SwapItems(const A, B: Integer);
    procedure SwapNodesText(const A, B: TTreeNode);
    procedure OnMergeFinished(const AVectorItem: IVectorDataItem);
  public
    procedure AddPoly(
      const APoly: IGeometryLonLatPolygon;
      const AInfo: IVectorDataItemMainInfo
    );
    procedure Clear;
  public
    constructor Create(
      AOwner: TComponent;
      AParent: TWinControl;
      const AAppClosingNotifier: INotifierOneOperation;
      const AVectorDataFactory: IVectorDataFactory;
      const AVectorGeometryLonLatFactory: IGeometryLonLatFactory;
      const AMapGoto: IMapViewGoto
    ); reintroduce;
    destructor Destroy; override;
  end;

implementation

uses
  t_GeoTypes;

resourcestring
  rsSubject = '[subject]';
  rsClip = '[clip]';

{$R *.dfm}

procedure MarkAsSubject(ANode: TTreeNode); inline;
begin
  if Pos(rsSubject, ANode.Text) = 0 then begin
    ANode.Text := StringReplace(ANode.Text, rsClip, '', [rfReplaceAll, rfIgnoreCase]);
    ANode.Text := Trim(ANode.Text) + ' ' + rsSubject;
  end;
end;

procedure MarkAsClip(ANode: TTreeNode); inline;
begin
  if Pos(rsClip, ANode.Text) = 0 then begin
    ANode.Text := StringReplace(ANode.Text, rsSubject, '', [rfReplaceAll, rfIgnoreCase]);
    ANode.Text := Trim(ANode.Text) + ' ' + rsClip;
  end;
end;

procedure CopyItem(const ASrc: TMergePolygonsItem; out ADest: TMergePolygonsItem); inline;
begin
  ADest.Name := ASrc.Name;
  ADest.VectorInfo := ASrc.VectorInfo;
  ADest.MultiPolygon := ASrc.MultiPolygon;
  ADest.SinglePolygon := ASrc.SinglePolygon;
end;

procedure InitItem(
  const APoly: IGeometryLonLatPolygon;
  const AInfo: IVectorDataItemMainInfo;
  out AItem: TMergePolygonsItem
);
begin
  AItem.VectorInfo := AInfo;
  AItem.MultiPolygon := nil;
  AItem.SinglePolygon := nil;

  if Supports(APoly, IGeometryLonLatMultiPolygon, AItem.MultiPolygon) then begin
    if AItem.MultiPolygon.Count = 1 then begin
      AItem.SinglePolygon := AItem.MultiPolygon.Item[0];
      AItem.MultiPolygon := nil;
    end;
  end else begin
    if not Supports(APoly, IGeometryLonLatSinglePolygon, AItem.SinglePolygon) then begin
      raise Exception.Create('Unsupported GeometryLonLatPolygon interface!');
    end;
  end;

  if Assigned(AItem.MultiPolygon) then begin
    AItem.Name := AInfo.Name + ' (' + 'Multi ' + IntToStr(AItem.MultiPolygon.Count) + ')';
  end else begin
    AItem.Name := AInfo.Name + ' (' + 'Single' + ')';
  end;
end;

{ TfrMergePolygons }

constructor TfrMergePolygons.Create(
  AOwner: TComponent;
  AParent: TWinControl;
  const AAppClosingNotifier: INotifierOneOperation;
  const AVectorDataFactory: IVectorDataFactory;
  const AVectorGeometryLonLatFactory: IGeometryLonLatFactory;
  const AMapGoto: IMapViewGoto
);
begin
  inherited Create(AOwner);

  Parent := AParent;
  FMapGoto := AMapGoto;

  SetLength(FItems, 0);
  tbxOperation.ItemIndex := Integer(moOR);

  FMergeProcessor :=
    TMergePolygonsProcessor.Create(
      AAppClosingNotifier,
      AVectorDataFactory,
      AVectorGeometryLonLatFactory
    );
end;

destructor TfrMergePolygons.Destroy;
begin
  FreeAndNil(FMergeProcessor);
  inherited Destroy;
end;

procedure TfrMergePolygons.AddPoly(
  const APoly: IGeometryLonLatPolygon;
  const AInfo: IVectorDataItemMainInfo
);
var
  I: Integer;
  VItem: TMergePolygonsItem;
begin
  Assert(Assigned(APoly));
  Assert(Assigned(AInfo));
  
  InitItem(APoly, AInfo, VItem);

  if not IsDublicate(VItem) then begin
    I := Length(FItems);
    SetLength(FItems, I+1);

    CopyItem(VItem, FItems[I]);

    tvPolygonsList.Items.AddChildObject(nil, FItems[I].Name, Pointer(I));
  end;
end;

function TfrMergePolygons.IsDublicate(const AItem: TMergePolygonsItem): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to Length(FItems) - 1 do begin
    if Assigned(FItems[I].MultiPolygon) and Assigned(AItem.MultiPolygon) then begin
      if FItems[I].MultiPolygon.IsSame(AItem.MultiPolygon) then begin
        Exit;
      end;
    end else if Assigned(FItems[I].SinglePolygon) and Assigned(AItem.SinglePolygon) then begin
      if FItems[I].SinglePolygon.IsSame(AItem.SinglePolygon) then begin
        Exit;
      end;
    end;
  end;
  Result := False;
end;

procedure TfrMergePolygons.tbxMergeClick(Sender: TObject);
var
  VOperation: TMergeOperation;
begin
  VOperation := TMergeOperation(tbxOperation.ItemIndex);
  Self.Enabled := False;
  //ToDo: Show progress info
  FMergeProcessor.MergeAsync(FItems, VOperation, Self.OnMergeFinished);
end;

procedure TfrMergePolygons.OnMergeFinished(const AVectorItem: IVectorDataItem);
begin
  //ToDo: Close progress info
  Self.Enabled := True;
  if Assigned(AVectorItem) then begin
    //ToDo: Draw item on map
  end;
end;

procedure TfrMergePolygons.tbxUpClick(Sender: TObject);
var
  I, J: Integer;
  VNode, VPrev: TTreeNode;
begin
  tvPolygonsList.Items.BeginUpdate;
  try
    VNode := tvPolygonsList.Selected;
    if Assigned(VNode) then begin
      VPrev := VNode.GetPrev;
      if Assigned(VPrev) then begin
        I := Integer(VNode.Data);
        J := Integer(VPrev.Data);
        SwapItems(I, J);
        SwapNodesText(VNode, VPrev);
        tvPolygonsList.Select(VPrev);
      end;
    end;
  finally
    tvPolygonsList.Items.EndUpdate;
  end;
end;

procedure TfrMergePolygons.tbxDelClick(Sender: TObject);
var
  I, J: Integer;
  VDelIndex: Integer;
  VNode: TTreeNode;
  VItems: TMergePolygonsItemArray;
begin
  VNode := tvPolygonsList.Selected;
  if Assigned(VNode) then begin
    VDelIndex := Integer(VNode.Data);
    SetLength(VItems, Length(FItems)-1);
    J := 0;
    for I := 0 to Length(FItems) - 1 do begin
      if I <> VDelIndex then begin
        CopyItem(FItems[I], VItems[J]);
        Inc(J);
      end;
    end;
    FItems := VItems;
    RebuildTree;
  end;
end;

procedure TfrMergePolygons.tbxDownClick(Sender: TObject);
var
  I, J: Integer;
  VNode, VNext: TTreeNode;
begin
  tvPolygonsList.Items.BeginUpdate;
  try
    VNode := tvPolygonsList.Selected;
    if Assigned(VNode) then begin
      VNext := VNode.GetNext;
      if Assigned(VNext) then begin
        I := Integer(VNode.Data);
        J := Integer(VNext.Data);
        SwapItems(I, J);
        SwapNodesText(VNode, VNext);
        tvPolygonsList.Select(VNext);
      end;
    end;
  finally
    tvPolygonsList.Items.EndUpdate;
  end;
end;

procedure TfrMergePolygons.tvPolygonsListAddition(Sender: TObject; Node: TTreeNode);
var
  I: Integer;
begin
  tvPolygonsList.Items.BeginUpdate;
  try
    for I := 0 to tvPolygonsList.Items.Count - 1 do begin
      if Integer(tvPolygonsList.Items[I].Data) <> 0 then begin
        MarkAsClip(tvPolygonsList.Items[I]);
      end else begin
        MarkAsSubject(tvPolygonsList.Items[I]);
      end;
    end;
  finally
    tvPolygonsList.Items.EndUpdate;
  end;
end;

procedure TfrMergePolygons.tvPolygonsListDblClick(Sender: TObject);
var
  I: Integer;
  VNode: TTreeNode;
  VGoToPoint: TDoublePoint;
begin
  VNode := tvPolygonsList.Selected;
  if Assigned(VNode) then begin
    I := Integer(VNode.Data);
    if Assigned(FItems[I].MultiPolygon) then begin
      VGoToPoint := FItems[I].MultiPolygon.GetGoToPoint;
    end else begin
      VGoToPoint := FItems[I].SinglePolygon.GetGoToPoint;
    end;
    FMapGoto.GotoLonLat(VGoToPoint, False);
  end;
end;

procedure TfrMergePolygons.Clear;
begin
  tvPolygonsList.Items.Clear;
  SetLength(FItems, 0);
end;

procedure TfrMergePolygons.RebuildTree;
var
  I: Integer;
begin
  tvPolygonsList.Items.BeginUpdate;
  try
    tvPolygonsList.Items.Clear;
    for I := 0 to Length(FItems) - 1 do begin
      tvPolygonsList.Items.AddChildObject(nil, FItems[I].Name, Pointer(I));
    end;
  finally
    tvPolygonsList.Items.EndUpdate;
  end;
end;

procedure TfrMergePolygons.SwapItems(const A, B: Integer);
var
  VTmp: TMergePolygonsItem;
begin
  CopyItem(FItems[A], VTmp);
  CopyItem(FItems[B], FItems[A]);
  CopyItem(VTmp, FItems[B]);
end;

procedure TfrMergePolygons.SwapNodesText(const A, B: TTreeNode);
var
  I: Integer;
begin
  I := Integer(A.Data);

  A.Text := FItems[I].Name;

  if I = 0 then begin
    MarkAsSubject(A);
  end else begin
    MarkAsClip(A);
  end;

  I := Integer(B.Data);

  B.Text := FItems[I].Name;

  if I = 0 then begin
    MarkAsSubject(B);
  end else begin
    MarkAsClip(B);
  end;
end;

end.