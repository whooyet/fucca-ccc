#include <chat-processor>
#include <fucca_group>

new Handle:kv[500] = {INVALID_HANDLE, ...};
new MaxItem;

enum ccc_enum
{
	String:Tag[256],
	String:TagColor[64],
	String:NameColor[64],
	String:ChatColor[64],
	bool:TagCheck
};

new CCC[33][ccc_enum];

new Handle:db = INVALID_HANDLE;

public Plugin myinfo = 
{
	name = "Simple Fucca CCC",
	author = "뿌까",
	description = "하하하하",
	version = "1.0",
	url = "x"
};

public OnPluginStart()
{
	ConfigFucca();
	RegConsoleCmd("sm_ccc", ccc);
	
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
	
	decl String:error[256];
	error[0] = '\0';
    
	if(SQL_CheckConfig("ccc")) db = SQL_Connect("ccc", true, error, sizeof(error));
	
	if(db==INVALID_HANDLE || error[0])
	{
		LogError("[ccc] Could not connect to ccc database: %s", error);
		return;
    }	
	
	PrintToServer("[ccc] Connection successful.");
	
	SQL_SetCharset(db, "utf8");
	SQL_TQuery(db, SQLErrorCallback, "create table if not exists ccc(steamid varchar(64) not null PRIMARY KEY, name varchar(256) NULL DEFAULT '0', tag varchar(256) NULL DEFAULT '', tag_color varchar(64) NULL DEFAULT '', name_color varchar(64) NULL DEFAULT '', chat_color varchar(64) NULL DEFAULT '') ENGINE=MyISAM DEFAULT CHARSET=utf8;");

}

public OnClientPutInServer(client)
{
	Format(CCC[client][Tag], 256, "");
	Format(CCC[client][TagColor], 64, "");
	Format(CCC[client][NameColor], 64, "");
	CCC[client][TagCheck] = false;
	CreateTimer(0.5, SqlData, client);
}

public Action:Command_Say(client, args)
{
	decl String:CurrentChat[256], String:SteamID[32];

	if(GetCmdArgString(CurrentChat, sizeof(CurrentChat)) < 1 || (client == 0) || IsChatTrigger()) return Plugin_Continue;
	StripQuotes(CurrentChat);
	
	new String:query[256];
	GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));
	
	if(CCC[client][TagCheck])
	{
		Format(CCC[client][Tag], 256, "%s", CurrentChat);
		
		Format(query, sizeof(query), "UPDATE ccc SET tag = '%s' WHERE steamid='%s'", CurrentChat, SteamID);
		SQL_TQuery(db, SQLErrorCallback, query);
		
		PrintToChat(client, "\x03적용되었습니다.");
		CCC[client][TagCheck] = false;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:ccc(client, args)
{
	if(!IsClientGroup(client))
	{
		PrintToChat(client, "\x03당신은 그룹원이 아닙니다");
		return Plugin_Handled;
	}
	new Handle:info = CreateMenu(SelectCCC);
	SetMenuTitle(info, "태그 설정");
	AddMenuItem(info, "tag name", "태그 설정");  
	AddMenuItem(info, "tag color", "태그 색 설정");  
	AddMenuItem(info, "name color", "이름 색 설정");  
	AddMenuItem(info, "chat color", "채팅 색 설정");  
	SetMenuExitButton(info, true);

	DisplayMenu(info, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public SelectCCC(Handle:menu, MenuAction:action, client, select)
{
	if(action == MenuAction_Select)
	{ 
		if(select == 0)
		{
			CCC[client][TagCheck] = true;
			PrintToChat(client, "\x03채팅창에 태그를 입력하세요");
		}
		else if(select == 1) CCCMenu(client, 1);
		else if(select == 2) CCCMenu(client, 2);
		else if(select == 3) CCCMenu(client, 3);
	}
	else if(action == MenuAction_End) CloseHandle(menu);
}

stock CCCMenu(client, num)
{
	new Handle:info = CreateMenu(SelectColor);
	SetMenuTitle(info, "색깔 / Color");
	
	decl String:ColorName[256], String:Hex[24]; new String:temp[100];
	for(new i = 0 ; i < MaxItem ; i++)
	{
		if(kv[i] != INVALID_HANDLE)
		{
			GetArrayString(kv[i], 0, ColorName, sizeof(ColorName));
			GetArrayString(kv[i], 1, Hex, sizeof(Hex));
		}
		if(num == 1) Format(temp, sizeof(temp), "tag_%s", Hex);
		else if(num == 2) Format(temp, sizeof(temp), "name_%s", Hex);
		else if(num == 3) Format(temp, sizeof(temp), "chat_%s", Hex);
		
		AddMenuItem(info, temp, ColorName); 
	}
	SetMenuExitButton(info, true);

	DisplayMenu(info, client, MENU_TIME_FOREVER);
}

public SelectColor(Handle:menu, MenuAction:action, client, select)
{
	if(action == MenuAction_Select)
	{ 
		decl String:info[100], String:aa[2][100], String:SteamID[32];
		GetMenuItem(menu, select, info, sizeof(info));
		ExplodeString(info, "_", aa, 2, 100);
		
		GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));
		new String:query[256];
		
		if(StrEqual(aa[0], "tag"))
		{
			Format(CCC[client][TagColor], 64, aa[1]);
			Format(query, sizeof(query), "UPDATE ccc SET tag_color = '%s' WHERE steamid='%s'", aa[1], SteamID);
		}
	
		else if(StrEqual(aa[0], "name"))
		{
			Format(CCC[client][NameColor], 64, aa[1]);
			Format(query, sizeof(query), "UPDATE ccc SET name_color = '%s' WHERE steamid='%s'", aa[1], SteamID);
		}
		else if(StrEqual(aa[0], "chat"))
		{
			Format(CCC[client][ChatColor], 64, aa[1]);
			Format(query, sizeof(query), "UPDATE ccc SET chat_color = '%s' WHERE steamid='%s'", aa[1], SteamID);
		}
		PrintToChat(client, "\x03설정되었습니다.");
		SQL_TQuery(db, SQLErrorCallback, query);
	}
	else if(action == MenuAction_End) CloseHandle(menu);
}

public Action: CP_OnChatMessage(int& client, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	if(!IsClientGroup(client)) return Plugin_Continue;
	if(!StrEqual(CCC[client][Tag], "")) // 태그가 있는경우
	{
		if(StrEqual(CCC[client][TagColor], "")) // 태그 색이 없는 경우
		{
			if(StrEqual(CCC[client][NameColor], "")) Format(name, MAXLENGTH_NAME, "%s \x03%s", CCC[client][Tag], name);
			else Format(name, MAXLENGTH_NAME, "%s \x07%s%s", CCC[client][Tag], CCC[client][NameColor], name);
		}
		else
		{
			if(StrEqual(CCC[client][NameColor], "")) Format(name, MAXLENGTH_NAME, "\x07%s%s \x03%s", CCC[client][TagColor], CCC[client][Tag], name);
			else Format(name, MAXLENGTH_NAME, "\x07%s%s \x07%s%s", CCC[client][TagColor], CCC[client][Tag], CCC[client][NameColor], name);
		}
	}
	else if(!StrEqual(CCC[client][NameColor], "")) Format(name, MAXLENGTH_NAME, "\x07%s%s", CCC[client][NameColor], name);
	if(!StrEqual(CCC[client][ChatColor], "")) Format(message, MAXLENGTH_MESSAGE, "\x07%s%s", CCC[client][ChatColor], message);
	return Plugin_Changed;
}

public Action:SqlData(Handle:Timer, any:client)
{
	new String:SteamID[64], String:query[256];
	GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));
		
	Format(query, 256, "select * from ccc where steamid = '%s';", SteamID);
	if(!IsFakeClient(client)) SQL_TQuery(db, SQLQueryLoad, query, client, DBPrio_High);
}

public SQLQueryLoad(Handle:owner, Handle:hndl, const String:error[], any:client) 
{
	if(!IsClientInGame(client)) return;
	if(hndl == INVALID_HANDLE) LogError("Query failed: %s", error);
	else if(SQL_GetRowCount(hndl) > 0)
	{
		if(SQL_HasResultSet(hndl))
		{
			while(SQL_FetchRow(hndl))
			{
				decl String:tag[64], String:tagc[64], String:namec[64], String:chatc[64], String:SteamID[32];
				decl String:old_name[MAX_NAME_LENGTH], String:new_name[(MAX_NAME_LENGTH*2)+1], String:query[256];
				
				GetClientName(client, old_name, sizeof(old_name));
				SQL_EscapeString(db, old_name, new_name, sizeof(new_name));
				GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));
				
				SQL_FetchString(hndl, 2, tag, sizeof(tag));
				SQL_FetchString(hndl, 3, tagc, sizeof(tagc));
				SQL_FetchString(hndl, 4, namec, sizeof(namec));
				SQL_FetchString(hndl, 5, chatc, sizeof(chatc));
				
				Format(query, sizeof(query), "UPDATE ccc SET name='%s' WHERE steamid='%s'", new_name, SteamID);
				SQL_TQuery(db, SQLErrorCallback, query);

				if(!StrEqual(tag, "")) Format(CCC[client][Tag], 256, tag);
				if(!StrEqual(tagc, "")) Format(CCC[client][TagColor], 64, tagc);
				if(!StrEqual(namec, "")) Format(CCC[client][NameColor], 64, namec);
				if(!StrEqual(chatc, "")) Format(CCC[client][ChatColor], 64, chatc);
			}
		}
	}
	else
	{
		decl String:SteamID[32], String:query[256];
		GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));

		Format(query, 256, "insert into ccc (steamid) VALUES ('%s');", SteamID);
		SQL_TQuery(db, SQLErrorCallback, query);
	}
}

public SQLErrorCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if(!StrEqual("", error)) LogError("Query failed: %s", error);
    return false;
}

public OnMapStart() ConfigFucca();
public OnMapEnd() for(new i = 0 ; i < 500 && i < MaxItem; i++) if(kv[i] != INVALID_HANDLE) CloseHandle(kv[i]);

public ConfigFucca()
{
	decl String:strPath[192], String:szBuffer[256];
	BuildPath(Path_SM, strPath, sizeof(strPath), "configs/fucca_ccc.cfg");
	new count = 0;
	
	new Handle:DB = CreateKeyValues("ccc");
	FileToKeyValues(DB, strPath);

	if(KvGotoFirstSubKey(DB))
	{
		do
		{
			kv[count] = CreateArray(540);
			
			KvGetSectionName(DB, szBuffer, sizeof(szBuffer));
			PushArrayString(kv[count], szBuffer);		
			
			KvGetString(DB, "color", szBuffer, sizeof(szBuffer));
			PushArrayString(kv[count], szBuffer);
			count++;
		}
		while(KvGotoNextKey(DB));
	}
	CloseHandle(DB);
	MaxItem = count;
}