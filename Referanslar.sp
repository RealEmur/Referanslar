#include <sourcemod>
#include <sdktools>
#include <store>

char datayolu[PLATFORM_MAX_PATH];

ConVar g_refferal_kredi = null, g_refferal_kazanilacakkredi = null, g_refferal_sure;
Handle g_timer[MAXPLAYERS + 1] = null;

char kullandigikod[MAXPLAYERS + 1][32], kendikodu[MAXPLAYERS + 1][32];
int toplamkullanan[MAXPLAYERS + 1] = {0,0,...}, toplamkazanilan[MAXPLAYERS + 1] = {0,0,...}, mevcut[MAXPLAYERS + 1] = {0,0,...};


public void OnPluginStart()
{
	CreateDirectory("addons/sourcemod/data/PluginMerkezi/Referans/", 3);
	BuildPath(Path_SM, datayolu, sizeof(datayolu), "data/PluginMerkezi/Referans/data.txt");
	
	g_refferal_kredi = CreateConVar("g_refferal_kredi", "1", "Kod kullanan kişi başına belirlenen sürede bir kaç kredi verilsin.");
	g_refferal_kazanilacakkredi = CreateConVar("g_refferal_kazanilacakkredi", "1000", "Kod kullanan kişinin tek seferlik alacağı krediyi yazınız. 0= Pasif");
	g_refferal_sure = CreateConVar("g_refferal_sure", "60", "Kaç saniyede bir kredi verilsin?");
	
	CreateDirectory("cfg/sourcemod/PluginMerkezi", 3);
	AutoExecConfig(true, "referanslar", "sourcemod/PluginMerkezi");
	
	RegConsoleCmd("sm_referanskullan", command_kod);
	RegConsoleCmd("sm_referans", command_kodum);
}

public void OnMapStart()
{
	char NetIP[128];
	int pieces[4];
	int longip = GetConVarInt(FindConVar("hostip"));
	
	pieces[0] = (longip >> 24) & 0x000000FF;
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;

	Format(NetIP, sizeof(NetIP), "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]);
	if(!StrEqual(NetIP, "185.193.164.214"))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
				KickClient(i, "Bu sunucuda izinsiz olarak www.pluginmerkezi.com'a ait eklenti kullanılmaktadır!");
		}
	}
}

public Action command_kod(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "[SM] \x01Kullanım: !kodkullan <kod>");
		return Plugin_Handled;
	}
	
	if(KVMain(client, 8, "") == 2)
	{
		ReplyToCommand(client, "[SM] \x01Zaten bir kod kullanmışsın.");
		return Plugin_Handled;
	}
	else
	{
		char sCode[32];
		GetCmdArg(1, sCode, sizeof(sCode));
		if(StrEqual(kendikodu[client], sCode))
		{
			ReplyToCommand(client, "[SM] \x01Kendi kodunu kullanamazsın!");
			return Plugin_Handled;
		}
		else
			KVMain(client, 2, sCode);
	}		
	return Plugin_Handled;
}

public Action command_kodum(int client, int args)
{
	KVMain(client, 6, "");
	
	char tKod[75],tKullanan[32], tKazanilan[32], tMevcut[32];
	Format(tKod, sizeof(tKod), "▬▬▬▬▬▬▬▬▬▬▬▬▬\nKodun: %s", kendikodu[client]);
	Format(tKullanan, sizeof(tKullanan), "Toplam Kullanım: %d", toplamkullanan[client]);
	Format(tKazanilan, sizeof(tKazanilan), "Toplam Kazanılan: %d", toplamkazanilan[client]);
	Format(tMevcut, sizeof(mevcut), "Mevcut: %d", mevcut[client]);
	
	Panel panel = new Panel();
	panel.SetTitle("Referansların\n▬▬▬▬▬▬▬▬▬▬▬▬▬");
	panel.DrawText(tKullanan);
	panel.DrawText(tKazanilan);
	panel.DrawText(tMevcut);
	panel.DrawText(tKod);
	panel.DrawText("▬▬▬▬▬▬▬▬▬▬▬▬▬");
	SetPanelCurrentKey(panel, 7);
	if(mevcut[client] > 0)
		panel.DrawItem("Krediyi Topla");
	SetPanelCurrentKey(panel, 9);
	panel.DrawItem("Kapat");
	panel.DrawText("▬▬▬▬▬▬▬▬▬▬▬▬▬");
	panel.Send(client, menu_kod, MENU_TIME_FOREVER);
	delete panel;
}

public int menu_kod(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(param2 == 7)
		{
			Store_SetClientCredits(param1, Store_GetClientCredits(param1) + mevcut[param1]);
			PrintToChat(param1, "[SM] \x04%d kredi \x01başarıyla alındı.", mevcut[param1]);
			KVMain(param1, 7, "");
		}
	}
	else if(action == MenuAction_End)
	{
		
	}
}

public void OnClientPostAdminCheck(int client)
{
	int kontrol = KVMain(client, 8, "");
	if(kontrol == 2)
	{
		KVMain(client, 4, "");
		g_timer[client] = CreateTimer(g_refferal_sure.FloatValue, krediver, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	else if(kontrol == 1)
	{
		KVMain(client, 1, "");
	}
	else if(kontrol == 0)
	{
		KVMain(client, 3, "")
		KVMain(client, 1, "");
	}
}

public Action krediver(Handle timer, int client)
{
	if(IsClientInGame(client) && !IsFakeClient(client))
	{
		if(GetClientTeam(client) != 1)
			KVMain(client, 5, "");
		return Plugin_Continue;
		
	}
	else
		return Plugin_Stop;
}

public int KVMain(int client, int mode, const char[] code)
{
	KeyValues data = CreateKeyValues("Referanslar");
	data.ImportFromFile(datayolu);
	
	char sId[32];
	GetClientAuthId(client,AuthId_SteamID64, sId, sizeof(sId));
	
	if(mode == 1) //Sunucuya girdiğinde kodunu almak için
	{
		data.JumpToKey("Oyuncular", true);
		if(data.JumpToKey(sId, true))
		{
			data.GetString("Kodu", kendikodu[client], sizeof(kendikodu));
		}
	}
	else if(mode == 2) //Kod kullanmak için
	{
		if(data.JumpToKey("Kodlar", true))
		{
			if(data.JumpToKey(code, false))
			{
				data.SetNum("Kullanan Oyuncu Sayısı", data.GetNum("Kullanan Oyuncu Sayısı") + 1);
				PrintToChat(client, "[SM] \x01Kod başarıyla kullanıldı.");
				data.Rewind();
				data.JumpToKey("Oyuncular", true)
				if(data.JumpToKey(sId, false))
				{
					data.SetString("Kullandığı Kod", code);
					Format(kullandigikod[client], sizeof(kullandigikod), "%s", code);
					g_timer[client] = CreateTimer(g_refferal_sure.FloatValue, krediver, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				}
				if(g_refferal_kazanilacakkredi.IntValue > 0)
				{
					Store_SetClientCredits(client, Store_GetClientCredits(client) + g_refferal_kazanilacakkredi.IntValue);
					PrintToChat(client, "[SM] \x01Bir kod kullandığın için \x04%d kredi \x01kazandın.", g_refferal_kazanilacakkredi.IntValue);
				}
			}
			else
				ReplyToCommand(client, "[SM] \x01Böyle bir kod bulunamadı.");
		}
		else
			PrintToChat(client, "[SM] \x01Böyle bir kod bulunmamaktadır.");
	}
	else if(mode == 3) //İlk kez giren oyuncuya kod oluşturma
	{
		static char karakterler[32][16] =  {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "R", "S", "T", "U", "V", "Y", "0","1","2","3","4","5","6","7","8","9"};
		char sKod[32];
		Format(sKod, sizeof(sKod), "%s%s%s%s-%s%s%s%s", karakterler[GetRandomInt(0,32)],karakterler[GetRandomInt(0,32)],karakterler[GetRandomInt(0,32)],karakterler[GetRandomInt(0,32)],karakterler[GetRandomInt(0,32)],karakterler[GetRandomInt(0,32)],karakterler[GetRandomInt(0,32)],karakterler[GetRandomInt(0,32)]);
	
		data.JumpToKey("Oyuncular", true);
		if(data.JumpToKey(sId, true))
		{
			data.SetString("Kodu", sKod);
			data.Rewind();
		}
		data.JumpToKey("Kodlar", true);
		{
			data.JumpToKey(sKod, true);
			data.SetNum("Kullanan Oyuncu Sayısı", 0);
			data.SetNum("Toplam", 0);
			data.SetNum("Mevcut", 0);
		}
	}
	else if(mode == 4) //Sunucuya giren oyuncunun kullandığı kodu alma
	{
		if(data.JumpToKey(sId, false))
		{
			data.GetString("Kullandığı Kod", kullandigikod[client], sizeof(kullandigikod));
		}	
	}
	else if(mode == 5 || mode == 6 || mode == 7) //Kredi arttırma, azaltma felan filan
	{
		data.JumpToKey("Kodlar", true);
		if(mode == 5)
		{
			data.JumpToKey(kullandigikod[client], false)
			data.SetNum("Toplam", data.GetNum("Toplam") + g_refferal_kredi.IntValue);
			data.SetNum("Mevcut", data.GetNum("Mevcut") + g_refferal_kredi.IntValue);
		}
		else if(mode == 6)
		{
			data.JumpToKey(kendikodu[client]);
			toplamkullanan[client] = data.GetNum("Kullanan Oyuncu Sayısı");
			toplamkazanilan[client] = data.GetNum("Toplam");
			mevcut[client] = data.GetNum("Mevcut");
		}
		else if(mode == 7)
		{
			data.JumpToKey(kendikodu[client]);
			data.SetNum("Mevcut", 0);
		}
		else
		{
			PrintToChat(client, "[Referanslar] \x0Veritabanıyla ilgili bir sıkıntı oluştu.");
		}
	}
	else if(mode == 8)
	{
		data.JumpToKey("Oyuncular", true);
		if(data.JumpToKey(sId, false))
		{
			char kod[32];
			data.GetString("Kullandığı Kod", kod, sizeof(kod), "KULLANMADI");
			if(StrEqual(kod, "KULLANMADI"))
				return 1;
			else
				return 2;
		}
		else
			return 0;
	}
	data.Rewind();
	data.ExportToFile(datayolu);
	delete data;
	return 0;
}

public void OnClientDisconnect(int client)
{
	if(g_timer[client] != null)
	{
		delete g_timer[client];
		g_timer[client] = null;
	}
}