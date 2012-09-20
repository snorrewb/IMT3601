class ProtoPlayerController extends UTPlayerController;

event Possess(Pawn inPawn, bool bVehicleTransition){
	Super.Possess(inPawn, bVehicleTransition);
	SetBehindView(true);	
}

defaultproperties {
	Name="Default__ProtoPlayerController"
}