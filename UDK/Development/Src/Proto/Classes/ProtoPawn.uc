class ProtoPawn extends UTPawn;

simulated function bool CalcCamera(float fDeltaTime, out vector out_CamLoc, out rotator out_CamRot, out float out_FOV)
{
	local vector start, end, hl, hn;
	local actor a;
	
	start = Location;
	
	if (Controller != none)
	{
		end = Location - Vector(Controller.Rotation) * 192.f;
	}
	else
	{
		end = Location - Vector(Rotation) * 192.f;
	}
	
	a = Trace(hl, hn, end, start, false);
	
	if (a != none)
	{
		out_CamLoc = hl;
	}
	else
	{
		out_CamLoc = end;
	}
	
	out_CamRot = Rotator(Location - out_CamLoc);
	return true;
}

defaultproperties{
	Begin Object Name=WPawnSkeletalMeshComponent
		bOwnerNoSee=false
	End Object
	Name="Default__ProtoPawn"

	GroundSpeed=600.0
}