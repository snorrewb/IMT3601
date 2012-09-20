/**
 * Copyright 1998-2012 Epic Games, Inc. All Rights Reserved.
 *
 * Provides the interface for registering and querying users
 */
class McpUserManagerBase extends McpServiceBase
	abstract
	config(Engine);

/** The class name to use in the factory method to create our instance */
var config String McpUserManagerClassName;

/**
 * Holds the status information for a MCP user
 */
struct McpUserStatus
{
	/** The McpId of the user */
	var String McpId;
	/** The device id this user was registered on */
	var string UDID;
	/** The country code that MCP thinks the user is from */
	var string CountryCode;
	/** The last activity date for this user */
	var string LastActiveDate;
	/** The number of days inactive */
	var int DaysInactive;
	/** Whether this user has been banned from playing this game */
	var bool bIsBanned;
};

/**
 * @return the object that implements this interface or none if missing or failed to create/load
 */
final static function McpUserManagerBase CreateInstance()
{
	local class<McpUserManagerBase> McpUserManagerBaseClass;
	local McpUserManagerBase NewInstance;

	McpUserManagerBaseClass = class<McpUserManagerBase>(DynamicLoadObject(default.McpUserManagerClassName,class'Class'));
	// If the class was loaded successfully, create a new instance of it
	if (McpUserManagerBaseClass != None)
	{
		NewInstance = new McpUserManagerBaseClass;
		NewInstance.Init();
	}

	return NewInstance;
}

/**
 * Creates a new user mapped to the UDID that is specified
 * Calls OnRegisterUserComplete when complete
 *
 * @param UDID the device id this create is coming from
 * @param ExistingMcpAuth existing auth ticket for user that has already registered
 */
function RegisterUserGenerated(string UDID, optional string ExistingMcpAuth);

/**
 * Maps a newly generated or existing Mcp id to the email/hash requested.
 * Note: email ownership/authenticity is not verified
 * Calls OnRegisterUserComplete when complete
 * 
 * @param Email user's email address to generate Mcp id for
 * @param UDID the UDID for the device
 * @param PasswordHash hash of the user's password to be stored securely on server
 * @param ExistingMcpAuth existing auth ticket for user that has already registered
 */
function RegisterUserEmail(string Email, string PasswordHash, string UDID, optional string ExistingMcpAuth);

/**
 * Maps a newly generated or existing Mcp id to the Facebook id/token requested.
 * Note: Facebook id authenticity is verified via the token
 * Calls OnRegisterUserComplete when complete
 * 
 * @param FacebookId user's FB id to generate Mcp id for
 * @param UDID the UDID for the device
 * @param FacebookAuthToken FB auth token obtained by signing in to FB
 * @param ExistingMcpAuth existing auth ticket for user that has already registered
 */
function RegisterUserFacebook(string FacebookId, string FacebookAuthToken, string UDID, optional string ExistingMcpAuth);

/**
 * Called once the results come back from the server to indicate success/failure of the operation
 *
 * @param McpId the id of the user that was just created
 * @param UDID the UDID for the device
 * @param bWasSuccessful whether the mapping succeeded or not
 * @param Error string information about the error (if an error)
 */
delegate OnRegisterUserComplete(string McpId, string UDID, bool bWasSuccessful, String Error);

/**
 * Queries the backend for the status of a users
 * 
 * @param McpId the id of the user to get the status for
 * @param bShouldUpdateLastActive if true, the act of getting the status updates the active time stamp
 */
function QueryUser(string McpId, optional bool bShouldUpdateLastActive);

/**
 * Queries the backend for the status of a list of users
 * 
 * @param McpIds the set of ids to get read the status of
 */
function QueryUsers(const out array<String> McpIds);

/**
 * Called once the query results come back from the server to indicate success/failure of the request
 *
 * @param bWasSuccessful whether the query succeeded or not
 * @param Error string information about the error (if an error)
 */
delegate OnQueryUsersComplete(bool bWasSuccessful, String Error);

/**
 * Returns the set of user statuses queried so far
 * 
 * @param Users the out array that gets the copied data
 */
function GetUsers(out array<McpUserStatus> Users);

/**
 * Deletes all data for a user
 * 
 * @param McpId the user that is being expunged from the system
 */
function DeleteUser(string McpId);

/**
 * Called once the delete request completes
 *
 * @param bWasSuccessful whether the request succeeded or not
 * @param Error string information about the error (if an error)
 */
delegate OnDeleteUserComplete(bool bWasSuccessful, String Error);
