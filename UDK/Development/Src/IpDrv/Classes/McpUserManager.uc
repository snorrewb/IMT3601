/**
 * Copyright 1998-2012 Epic Games, Inc. All Rights Reserved.
 *
 * Concrete implementation for mapping McpIds to external account ids
 */
class McpUserManager extends McpUserManagerBase;

/**
 * Holds the set of user statuses that were downloaded
 */
var array<McpUserStatus> UserStatuses;

/** The URL to use when making user registration requests to generate an id */
var config String RegisterUserMcpUrl;

/** The URL to use when making user registration requests via email/pass */
var config String RegisterUserEmailUrl;

/** The URL to use when making user registration requests via Facebook id/token */
var config String RegisterUserFacebookUrl;

/** The URL to use when making user query requests */
var config String QueryUserUrl;

/** The URL to use when making querying for multiple user statuses */
var config String QueryUsersUrl;

/** The URL to use when making user deletion requests */
var config String DeleteUserUrl;

/** Holds the state information for an outstanding user register request */
struct RegisterUserRequest
{
	/** The UDID being registered */
	var string UDID;
	/** The MCP id that was returned by the backend */
	var string McpId;
	/** The request object for this request */
	var HttpRequestInterface Request;
};

/** The set of add mapping requests that are pending */
var array<RegisterUserRequest> RegisterUserRequests;

/** The set of query requests that are pending */
var array<HttpRequestInterface> QueryUsersRequests;

/** The set of delete requests that are pending */
var array<HttpRequestInterface> DeleteUserRequests;

/**
 * Creates a new user mapped to the UDID that is specified
 * 
 * @param UDID the device id this create is coming from
 * @param ExistingMcpAuth existing auth ticket for user that has already registered
 */
function RegisterUserGenerated(string UDID, optional string ExistingMcpAuth)
{
	local String Url;
	local HttpRequestInterface Request;
	local int AddAt;

	Request = class'HttpFactory'.static.CreateRequest();
	if (Request != none)
	{
		Url = GetBaseURL() $ RegisterUserMcpUrl $ GetAppAccessURL() $
			"&udid=" $ UDID;

		// Build our web request with the above URL
		Request.SetURL(Url);
		Request.SetVerb("POST");
		Request.OnProcessRequestComplete = OnRegisterUserRequestComplete;
		// Store off the data for reporting later
		AddAt = RegisterUserRequests.Length;
		RegisterUserRequests.Length = AddAt + 1;
		RegisterUserRequests[AddAt].UDID = UDID;
		RegisterUserRequests[AddAt].Request = Request;

		// Now kick off the request
		if (!Request.ProcessRequest())
		{
			`Log("Failed to start RegisterUser web request for URL(" $ Url $ ")");
		}
		`Log("URL is " $ Url);
	}
}

/**
 * Called once the request/response has completed. Used to process the register user result and notify any
 * registered delegate
 * 
 * @param Request the request object that was used
 * @param Response the response object that was generated
 * @param bWasSuccessful whether or not the request completed successfully
 */
function OnRegisterUserRequestComplete(HttpRequestInterface Request, HttpResponseInterface Response, bool bWasSuccessful)
{
	local int Index;
	local int AddAt;
	local int ResponseCode;
	local int UserIndex;
	local string McpId;
	local bool bWasFound;

	// Search for the corresponding entry in the array
	Index = RegisterUserRequests.Find('Request', Request);
	if (Index != INDEX_NONE)
	{
		ResponseCode = 500;
		if (Response != none)
		{
			ResponseCode = Response.GetResponseCode();
		}
		// Both of these need to be true for the request to be a success
		bWasSuccessful = bWasSuccessful && ResponseCode == 200;
		if (bWasSuccessful)
		{
			McpId = Response.GetContentAsString();
			RegisterUserRequests[Index].McpId = McpId;
			if (McpId != "")
			{
				// Search the array for any existing adding only when missing
				for (UserIndex = 0; UserIndex < UserStatuses.Length && !bWasFound; UserIndex++)
				{
					bWasFound = McpId == UserStatuses[UserIndex].McpId;
				}
				// Add this one since it wasn't found
				if (!bWasFound)
				{
					AddAt = UserStatuses.Length;
					UserStatuses.Length = AddAt + 1;
					UserStatuses[AddAt].McpId = McpId;
					UserStatuses[AddAt].UDID = RegisterUserRequests[Index].UDID;
				}
			}
		}
		// Notify anyone waiting on this
		OnRegisterUserComplete(RegisterUserRequests[Index].McpId,
			RegisterUserRequests[Index].UDID,
			bWasSuccessful,
			Response.GetContentAsString());
		`Log("Register user McpId(" $ RegisterUserRequests[Index].McpId $ "), UDID(" $
			RegisterUserRequests[Index].UDID $ ") was successful " $ bWasSuccessful $
			" with ResponseCode(" $ ResponseCode $ ")");
		RegisterUserRequests.Remove(Index,1);
	}
}

/**
 * Maps a newly generated or existing Mcp id to the email/hash requested.
 * Note: email ownership/authenticity is not verified
 * 
 * @param Email user's email address to generate Mcp id for
 * @param UDID the UDID for the device
 * @param PasswordHash hash of the user's password to be stored securely on server
 * @param ExistingMcpAuth existing auth ticket for user that has already registered
 */
function RegisterUserEmail(string Email, string PasswordHash, string UDID, optional string ExistingMcpAuth)
{
	local String Url;
	local HttpRequestInterface Request;
	local int AddAt;

	Request = class'HttpFactory'.static.CreateRequest();
	if (Request != none)
	{
		//@todo - verify email format?

		Url = GetBaseURL() $ RegisterUserEmailUrl $ GetAppAccessURL() $
			"&email=" $ Email $
			"&passwordhash=" $ PasswordHash $
			"&udid=" $ UDID;

		if (Len(ExistingMcpAuth) > 0)
		{
			Url $= "&authticket=" $ ExistingMcpAuth;
		}

		// Build our web request with the above URL
		Request.SetURL(Url);
		Request.SetVerb("POST");
		Request.OnProcessRequestComplete = OnRegisterUserEmailRequestComplete;
		// Store off the data for reporting later
		AddAt = RegisterUserRequests.Length;
		RegisterUserRequests.Length = AddAt + 1;
		RegisterUserRequests[AddAt].UDID = UDID;
		RegisterUserRequests[AddAt].Request = Request;

		// Now kick off the request
		if (!Request.ProcessRequest())
		{
			`Log("Failed to start RegisterUserEmail web request for URL(" $ Url $ ")");
		}
		`Log("URL is " $ Url);
	}
}

/**
 * Called once the request/response has completed. Used to process the register user result and notify any
 * registered delegate
 * 
 * @param Request the request object that was used
 * @param Response the response object that was generated
 * @param bWasSuccessful whether or not the request completed successfully
 */
function OnRegisterUserEmailRequestComplete(HttpRequestInterface Request, HttpResponseInterface Response, bool bWasSuccessful)
{
	OnRegisterUserRequestComplete(Request,Response,bWasSuccessful);
}

/**
 * Maps a newly generated or existing Mcp id to the Facebook id/token requested.
 * Note: Facebook id authenticity is verified via the token
 * 
 * @param FacebookId user's FB id to generate Mcp id for
 * @param UDID the UDID for the device
 * @param FacebookAuthToken FB auth token obtained by signing in to FB
 * @param ExistingMcpAuth existing auth ticket for user that has already registered
 */
function RegisterUserFacebook(string FacebookId, string FacebookAuthToken, string UDID, optional string ExistingMcpAuth)
{
	local String Url;
	local HttpRequestInterface Request;
	local int AddAt;

	Request = class'HttpFactory'.static.CreateRequest();
	if (Request != none)
	{
		Url = GetBaseURL() $ RegisterUserEmailUrl $ GetAppAccessURL() $
			"&facebookid=" $ FacebookId $
			"&facebooktoken=" $ FacebookAuthToken $
			"&udid=" $ UDID;

		if (Len(ExistingMcpAuth) > 0)
		{
			Url $= "&authticket=" $ ExistingMcpAuth;
		}

		// Build our web request with the above URL
		Request.SetURL(Url);
		Request.SetVerb("POST");
		Request.OnProcessRequestComplete = OnRegisterUserFacebookRequestComplete;
		// Store off the data for reporting later
		AddAt = RegisterUserRequests.Length;
		RegisterUserRequests.Length = AddAt + 1;
		RegisterUserRequests[AddAt].UDID = UDID;
		RegisterUserRequests[AddAt].Request = Request;

		// Now kick off the request
		if (!Request.ProcessRequest())
		{
			`Log("Failed to start RegisterUserFacebook web request for URL(" $ Url $ ")");
		}
		`Log("URL is " $ Url);
	}
}

/**
 * Called once the request/response has completed. Used to process the register user result and notify any
 * registered delegate
 * 
 * @param Request the request object that was used
 * @param Response the response object that was generated
 * @param bWasSuccessful whether or not the request completed successfully
 */
function OnRegisterUserFacebookRequestComplete(HttpRequestInterface Request, HttpResponseInterface Response, bool bWasSuccessful)
{
	OnRegisterUserRequestComplete(Request,Response,bWasSuccessful);
}

/**
 * Queries the backend for the status of a users
 * 
 * @param McpId the id of the user to get the status for
 * @param bShouldUpdateLastActive if true, the act of getting the status updates the active time stamp
 */
function QueryUser(string McpId, optional bool bShouldUpdateLastActive)
{
	local String Url;
	local HttpRequestInterface Request;
	local int AddAt;

	Request = class'HttpFactory'.static.CreateRequest();
	if (Request != none && McpId != "")
	{
		Url = GetBaseURL() $ QueryUserUrl $ GetAppAccessURL() $
			"&uniqueUserId=" $ McpId $ "&updateLastActive=" $ bShouldUpdateLastActive;

		// Build our web request with the above URL
		Request.SetURL(Url);
		Request.SetVerb("GET");
		Request.OnProcessRequestComplete = OnQueryUserRequestComplete;
		// Store off the data for reporting later
		AddAt = QueryUsersRequests.Length;
		QueryUsersRequests.Length = AddAt + 1;
		QueryUsersRequests[AddAt] = Request;

		// Now kick off the request
		if (!Request.ProcessRequest())
		{
			`Log("Failed to start QueryUser web request for URL(" $ Url $ ")");
		}
	}
}

/**
 * Called once the request/response has completed. Used to process the returned data and notify any
 * registered delegate
 * 
 * @param Request the request object that was used
 * @param Response the response object that was generated
 * @param bWasSuccessful whether or not the request completed successfully
 */
function OnQueryUserRequestComplete(HttpRequestInterface Request, HttpResponseInterface Response, bool bWasSuccessful)
{
	local int Index;
	local int AddAt;
	local int ResponseCode;
	local string JsonString;
	local JsonObject ParsedJson;
	local int UserIndex;
	local string McpId;
	local string UDID;
	local string CountryCode;
	local string LastActiveDate;
	local bool bIsBanned;
	local bool bWasFound;
	local int DaysInactive;

	// Search for the corresponding entry in the array
	Index = QueryUsersRequests.Find(Request);
	if (Index != INDEX_NONE)
	{
		ResponseCode = 500;
		if (Response != none)
		{
			ResponseCode = Response.GetResponseCode();
		}
		// Both of these need to be true for the request to be a success
		bWasSuccessful = bWasSuccessful && ResponseCode == 200;
		if (bWasSuccessful)
		{
			JsonString = Response.GetContentAsString();
			if (JsonString != "")
			{
// @todo joeg - Replace with Wes' ImportJson() once it's implemented
				// Parse the json
				ParsedJson = class'JsonObject'.static.DecodeJson(JsonString);
				McpId = ParsedJson.GetStringValue("unique_user_id");
				UDID = ParsedJson.GetStringValue("udid");
				CountryCode = ParsedJson.GetStringValue("country_code");
				bIsBanned = ParsedJson.GetBoolValue("is_banned");
				LastActiveDate = ParsedJson.GetStringValue("last_active_date");
				DaysInactive = ParsedJson.GetIntValue("days_inactive");
				bWasFound = false;
				// Search the array for any existing adding only when missing
				for (UserIndex = 0; UserIndex < UserStatuses.Length && !bWasFound; UserIndex++)
				{
					bWasFound = McpId == UserStatuses[UserIndex].McpId;
				}
				// Add this one since it wasn't found
				if (!bWasFound)
				{
					AddAt = UserStatuses.Length;
					UserStatuses.Length = AddAt + 1;
					UserStatuses[AddAt].McpId = McpId;
					UserStatuses[AddAt].UDID = UDID;
					UserStatuses[AddAt].CountryCode = CountryCode;
					UserStatuses[AddAt].bIsBanned = bIsBanned;
					UserStatuses[AddAt].LastActiveDate = LastActiveDate;
					UserStatuses[AddAt].DaysInactive = DaysInactive;
					`log("Added Status:" @ McpId @ UDID @ LastActiveDate @ DaysInactive);
				}
				else
				{
					`log("Added Updated:" @ McpId @ UDID @ LastActiveDate @ DaysInactive);
				}
			}
		}
		// Notify anyone waiting on this
		OnQueryUsersComplete(bWasSuccessful, Response.GetContentAsString());
		`Log("Query users was successful " $ bWasSuccessful $
			" with ResponseCode(" $ ResponseCode $ ")");
		QueryUsersRequests.Remove(Index,1);
	}
}

/**
 * Queries the backend for the status of a list of users
 * 
 * @param McpIds the set of ids to get read the status of
 */
function QueryUsers(const out array<String> McpIds)
{
	local String Url;
	local HttpRequestInterface Request;
	local int AddAt;
	local string JsonPayload;
	local int Index;

	Request = class'HttpFactory'.static.CreateRequest();
	if (Request != none)
	{
		Url = GetBaseURL() $ QueryUsersUrl $ GetAppAccessURL();

		// Make a json string from our list of ids
		JsonPayload = "[ ";
		for (Index = 0; Index < McpIds.Length; Index++)
		{
			JsonPayload $= "\"" $ McpIds[Index] $ "\"";
			// Only add the string if this isn't the last item
			if (Index + 1 < McpIds.Length)
			{
				JsonPayload $= ",";
			}
		}
		JsonPayload $= " ]";

		// Build our web request with the above URL
		Request.SetURL(Url);
		Request.SetContentAsString(JsonPayload);
		Request.SetVerb("POST");
		Request.SetHeader("Content-Type","multipart/form-data");
		Request.OnProcessRequestComplete = OnQueryUsersRequestComplete;
		// Store off the data for reporting later
		AddAt = QueryUsersRequests.Length;
		QueryUsersRequests.Length = AddAt + 1;
		QueryUsersRequests[AddAt] = Request;

		// Now kick off the request
		if (!Request.ProcessRequest())
		{
			`Log("Failed to start QueryUsers web request for URL(" $ Url $ ")");
		}
	}
}

/**
 * Called once the request/response has completed. Used to process the returned data and notify any
 * registered delegate
 * 
 * @param Request the request object that was used
 * @param Response the response object that was generated
 * @param bWasSuccessful whether or not the request completed successfully
 */
function OnQueryUsersRequestComplete(HttpRequestInterface Request, HttpResponseInterface Response, bool bWasSuccessful)
{
	local int Index;
	local int AddAt;
	local int ResponseCode;
	local string JsonString;
	local JsonObject ParsedJson;
	local int UserIndex;
	local int JsonIndex;
	local string McpId;
	local string UDID;
	local string CountryCode;
	local string LastActiveDate;
	local bool bIsBanned;
	local bool bWasFound;
	local int DaysInactive;

	// Search for the corresponding entry in the array
	Index = QueryUsersRequests.Find(Request);
	if (Index != INDEX_NONE)
	{
		ResponseCode = 500;
		if (Response != none)
		{
			ResponseCode = Response.GetResponseCode();
		}
		// Both of these need to be true for the request to be a success
		bWasSuccessful = bWasSuccessful && ResponseCode == 200;
		if (bWasSuccessful)
		{
			JsonString = Response.GetContentAsString();
			if (JsonString != "")
			{
// @todo joeg - Replace with Wes' ImportJson() once it's implemented
				// Parse the json
				ParsedJson = class'JsonObject'.static.DecodeJson(JsonString);
				// Add each returned user to the list if not already present
				for (JsonIndex = 0; JsonIndex < ParsedJson.ObjectArray.Length; JsonIndex++)
				{
					McpId = ParsedJson.ObjectArray[JsonIndex].GetStringValue("unique_user_id");
					UDID = ParsedJson.ObjectArray[JsonIndex].GetStringValue("udid");
					CountryCode = ParsedJson.ObjectArray[JsonIndex].GetStringValue("country_code");
					bIsBanned = ParsedJson.ObjectArray[JsonIndex].GetBoolValue("is_banned");
					LastActiveDate = ParsedJson.ObjectArray[JsonIndex].GetStringValue("last_active_date");
					DaysInactive = ParsedJson.ObjectArray[JsonIndex].GetIntValue("days_inactive");
					bWasFound = false;
					// Search the array for any existing adding only when missing
					for (UserIndex = 0; UserIndex < UserStatuses.Length && !bWasFound; UserIndex++)
					{
						bWasFound = McpId == UserStatuses[UserIndex].McpId;
					}
					// Add this one since it wasn't found
					if (!bWasFound)
					{
						AddAt = UserStatuses.Length;
						UserStatuses.Length = AddAt + 1;
						UserStatuses[AddAt].McpId = McpId;
						UserStatuses[AddAt].UDID = UDID;
						UserStatuses[AddAt].CountryCode = CountryCode;
						UserStatuses[AddAt].bIsBanned = bIsBanned;
						UserStatuses[AddAt].LastActiveDate = LastActiveDate;
						UserStatuses[AddAt].DaysInactive = DaysInactive;
					}
				}
			}
		}
		// Notify anyone waiting on this
		OnQueryUsersComplete(bWasSuccessful, Response.GetContentAsString());
		`Log("Query users was successful " $ bWasSuccessful $
			" with ResponseCode(" $ ResponseCode $ ")");
		QueryUsersRequests.Remove(Index,1);
	}
}

/**
 * Returns the set of user statuses queried so far
 * 
 * @param Users the out array that gets the copied data
 */
function GetUsers(out array<McpUserStatus> Users)
{
	Users = UserStatuses;
}

/**
 * Deletes all data for a user
 * 
 * @param McpId the user that is being expunged from the system
 */
function DeleteUser(string McpId)
{
	local String Url;
	local HttpRequestInterface Request;
	local int AddAt;

	Request = class'HttpFactory'.static.CreateRequest();
	if (Request != none)
	{
		Url = GetBaseURL() $ DeleteUserUrl $ GetAppAccessURL() $
			"&uniqueUserId=" $ McpId;

		// Build our web request with the above URL
		Request.SetURL(Url);
		Request.SetVerb("DELETE");
		Request.OnProcessRequestComplete = OnDeleteUserRequestComplete;
		// Store off the data for reporting later
		AddAt = DeleteUserRequests.Length;
		DeleteUserRequests.Length = AddAt + 1;
		DeleteUserRequests[AddAt] = Request;

		// Now kick off the request
		if (!Request.ProcessRequest())
		{
			`Log("Failed to start DeleteUser web request for URL(" $ Url $ ")");
		}
		`Log("URL is " $ Url);
	}
}

/**
 * Called once the delete request completes
 *
 * @param Request the request object that was used
 * @param Response the response object that was generated
 * @param bWasSuccessful whether or not the request completed successfully
 */
function OnDeleteUserRequestComplete(HttpRequestInterface Request, HttpResponseInterface Response, bool bWasSuccessful)
{
	local int Index;
	local int ResponseCode;

	// Search for the corresponding entry in the array
	Index = DeleteUserRequests.Find(Request);
	if (Index != INDEX_NONE)
	{
		ResponseCode = 500;
		if (Response != none)
		{
			ResponseCode = Response.GetResponseCode();
		}
		// Both of these need to be true for the request to be a success
		bWasSuccessful = bWasSuccessful && ResponseCode == 200;
		// Notify anyone waiting on this
		OnDeleteUserComplete(bWasSuccessful,
			Response.GetContentAsString());
		`Log("Delete user for URL(" $ Request.GetURL() $ ") successful " $ bWasSuccessful $
			" with ResponseCode(" $ ResponseCode $ ")");
		DeleteUserRequests.Remove(Index,1);
	}
}
