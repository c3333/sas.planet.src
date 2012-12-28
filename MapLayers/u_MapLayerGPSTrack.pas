unit u_MapLayerGPSTrack;

interface

uses
  GR32_Image,
  i_Notifier, 
  i_NotifierOperation,
  i_LocalCoordConverter,
  i_LocalCoordConverterFactorySimpe,
  i_BitmapLayerProvider,
  i_InternalPerformanceCounter,
  i_ViewPortState,
  i_SimpleFlag,
  i_MapLayerGPSTrackConfig,
  i_GPSRecorder,
  i_ImageResamplerConfig,
  u_TiledLayerWithThreadBase;

type
  TMapLayerGPSTrack = class(TTiledLayerWithThreadBase)
  private
    FConfig: IMapLayerGPSTrackConfig;
    FGPSRecorder: IGPSRecorder;

    FGetTrackCounter: IInternalPerformanceCounter;
    FGpsPosChangeFlag: ISimpleFlag;
    procedure OnConfigChange;
    procedure OnGPSRecorderChange;
    procedure OnTimer;
  protected
    function CreateLayerProvider(
      AOperationID: Integer;
      const ACancelNotifier: INotifierOperation;
      const ALayerConverter: ILocalCoordConverter
    ): IBitmapLayerProvider; override;
    procedure StartThreads; override;
  public
    constructor Create(
      const APerfList: IInternalPerformanceCounterList;
      const AAppStartedNotifier: INotifierOneOperation;
      const AAppClosingNotifier: INotifierOneOperation;
      AParentMap: TImage32;
      const AViewPortState: IViewPortState;
      const ATileMatrixDraftResamplerConfig: IImageResamplerConfig;
      const AConverterFactory: ILocalCoordConverterFactorySimpe;
      const ATimerNoifier: INotifier;
      const AConfig: IMapLayerGPSTrackConfig;
      const AGPSRecorder: IGPSRecorder
    );
  end;

implementation

uses
  i_TileMatrix,
  u_TileMatrixFactory,
  u_ListenerByEvent,
  u_SimpleFlagWithInterlock,
  u_BitmapLayerProviderByTrackPath;

{ TMapGPSLayerNew }

constructor TMapLayerGPSTrack.Create(
  const APerfList: IInternalPerformanceCounterList;
  const AAppStartedNotifier: INotifierOneOperation;
  const AAppClosingNotifier: INotifierOneOperation;
  AParentMap: TImage32;
  const AViewPortState: IViewPortState;
  const ATileMatrixDraftResamplerConfig: IImageResamplerConfig;
  const AConverterFactory: ILocalCoordConverterFactorySimpe;
  const ATimerNoifier: INotifier; const AConfig: IMapLayerGPSTrackConfig;
  const AGPSRecorder: IGPSRecorder
);
var
  VTileMatrixFactory: ITileMatrixFactory;
begin
  VTileMatrixFactory :=
    TTileMatrixFactory.Create(
      ATileMatrixDraftResamplerConfig,
      AConverterFactory
    );
  inherited Create(
    APerfList,
    AAppStartedNotifier,
    AAppClosingNotifier,
    AParentMap,
    AViewPortState.Position,
    AViewPortState.View,
    VTileMatrixFactory,
    ATimerNoifier,
    False,
    AConfig.ThreadConfig
  );
  FGPSRecorder := AGPSRecorder;
  FConfig := AConfig;

  FGetTrackCounter := PerfList.CreateAndAddNewCounter('GetTrack');
  FGpsPosChangeFlag := TSimpleFlagWithInterlock.Create;

  LinksList.Add(
    TNotifyNoMmgEventListener.Create(Self.OnConfigChange),
    FConfig.GetChangeNotifier
  );
  LinksList.Add(
    TNotifyNoMmgEventListener.Create(Self.OnTimer),
    ATimerNoifier
  );
  LinksList.Add(
    TNotifyNoMmgEventListener.Create(Self.OnGPSRecorderChange),
    FGPSRecorder.GetChangeNotifier
  );
end;

function TMapLayerGPSTrack.CreateLayerProvider(
  AOperationID: Integer;
  const ACancelNotifier: INotifierOperation;
  const ALayerConverter: ILocalCoordConverter
): IBitmapLayerProvider;
var
  VTrackColorer: ITrackColorerStatic;
  VPointsCount: Integer;
  VLineWidth: Double;
  VCounterContext: TInternalPerformanceCounterContext;
  VEnum: IEnumGPSTrackPoint;
begin
  Result := nil;
  FConfig.LockRead;
  try
    VPointsCount := FConfig.LastPointCount;
    VLineWidth := FConfig.LineWidth;
    VTrackColorer := FConfig.TrackColorerConfig.GetStatic;
  finally
    FConfig.UnlockRead
  end;

  if (VPointsCount > 1) then begin
    VCounterContext := FGetTrackCounter.StartOperation;
    try
      VEnum := FGPSRecorder.LastPoints(VPointsCount);
    finally
      FGetTrackCounter.FinishOperation(VCounterContext);
    end;
    Result :=
      TBitmapLayerProviderByTrackPath.Create(
        VPointsCount,
        VLineWidth,
        VTrackColorer,
        ALayerConverter.ProjectionInfo,
        VEnum
      );
  end;
end;

procedure TMapLayerGPSTrack.OnConfigChange;
begin
  ViewUpdateLock;
  try
    Visible := FConfig.Visible;
    SetNeedUpdateLayerProvider;
  finally
    ViewUpdateUnlock;
  end;
end;

procedure TMapLayerGPSTrack.OnGPSRecorderChange;
begin
  FGpsPosChangeFlag.SetFlag;
end;

procedure TMapLayerGPSTrack.OnTimer;
begin
  if FGpsPosChangeFlag.CheckFlagAndReset then begin
    ViewUpdateLock;
    try
      SetNeedUpdateLayerProvider;
    finally
      ViewUpdateUnlock;
    end;
  end;
end;

procedure TMapLayerGPSTrack.StartThreads;
begin
  inherited;
  OnConfigChange;
end;

end.

