/**
 * Some generic helpers functions.
 */

public bool IsGrenadeProjectile(const char[] className) {
    static char projectileTypes[][] = {
        "hegrenade_projectile",
        "smokegrenade_projectile",
        "decoy_projectile",
        "flashbang_projectile",
        "molotov_projectile",
    };

    return FindStringInArray2(projectileTypes, sizeof(projectileTypes), className) >= 0;
}

public bool IsGrenadeWeapon(const char[] weapon) {
    static char grenades[][] = {
        "incgrenade",
        "molotov",
        "hegrenade",
        "decoy",
        "flashbang",
        "smokegrenade",
    };

    return FindStringInArray2(grenades, sizeof(grenades), weapon) >= 0;
}

stock void TeleportToGrenadeHistoryPosition(int client, int index, MoveType moveType=MOVETYPE_WALK) {
    float origin[3];
    float angles[3];
    float velocity[3];
    g_GrenadeHistoryPositions[client].GetArray(index, origin, sizeof(origin));
    g_GrenadeHistoryAngles[client].GetArray(index, angles, sizeof(angles));
    TeleportEntity(client, origin, angles, velocity);
    SetEntityMoveType(client, moveType);
}

public bool TeleportToSavedGrenadePosition(int client, const char[] targetAuth, const char[] id) {
    float origin[3];
    float angles[3];
    float velocity[3];
    char description[GRENADE_DESCRIPTION_LENGTH];
    char category[GRENADE_CATEGORY_LENGTH];
    bool success = false;

    // update the client's current grenade id, if it was their grenade
    bool myGrenade;
    char clientAuth[AUTH_LENGTH];
    GetClientAuthId(client, AUTH_METHOD, clientAuth, sizeof(clientAuth));
    if (StrEqual(clientAuth, targetAuth)) {
        g_CurrentSavedGrenadeId[client] = StringToInt(id);
        myGrenade = true;
    } else {
        g_CurrentSavedGrenadeId[client] = -1;
        myGrenade = false;
    }

    if (g_GrenadeLocationsKv.JumpToKey(targetAuth)) {
        char targetName[MAX_NAME_LENGTH];
        char grenadeName[GRENADE_NAME_LENGTH];
        g_GrenadeLocationsKv.GetString("name", targetName, sizeof(targetName));

        if (g_GrenadeLocationsKv.JumpToKey(id)) {
            success = true;
            g_GrenadeLocationsKv.GetVector("origin", origin);
            g_GrenadeLocationsKv.GetVector("angles", angles);
            g_GrenadeLocationsKv.GetString("name", grenadeName, sizeof(grenadeName));
            g_GrenadeLocationsKv.GetString("description", description, sizeof(description));
            g_GrenadeLocationsKv.GetString("categories", category, sizeof(category));
            TeleportEntity(client, origin, angles, velocity);
            SetEntityMoveType(client, MOVETYPE_WALK);

            if (myGrenade) {
                PM_Message(client, "Teleporting to your grenade id %s, \"%s\".", id, grenadeName);
            } else {
                PM_Message(client, "Teleporting to %s's grenade id %s, \"%s\".", targetName, id, grenadeName);
            }

            if (!StrEqual(description, "")) {
                PM_Message(client, "Description: %s", description);
            }

            if (!StrEqual(category, "")) {
                ReplaceString(category, sizeof(category), ";", ", ");
                // Cut off the last two characters of the category string to avoid
                // an extraneous comma and space.
                int len = strlen(category);
                category[len - 2] = '\0';
                PM_Message(client, "Categories: %s", category);
            }

            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }

    return success;
}

public int SaveGrenadeToKv(int client, const float origin[3], const float angles[3], const char[] name) {
    g_UpdatedGrenadeKv = true;
    char auth[AUTH_LENGTH];
    char clientName[MAX_NAME_LENGTH];
    GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
    GetClientName(client, clientName, sizeof(clientName));
    g_GrenadeLocationsKv.JumpToKey(auth, true);
    g_GrenadeLocationsKv.SetString("name", clientName);
    int nadeId = g_GrenadeLocationsKv.GetNum("nextid", 1);
    g_GrenadeLocationsKv.SetNum("nextid", nadeId + 1);

    char idStr[GRENADE_ID_LENGTH];
    IntToString(nadeId, idStr, sizeof(idStr));
    g_GrenadeLocationsKv.JumpToKey(idStr, true);

    g_GrenadeLocationsKv.SetString("name", name);
    g_GrenadeLocationsKv.SetVector("origin", origin);
    g_GrenadeLocationsKv.SetVector("angles", angles);

    g_GrenadeLocationsKv.GoBack();
    g_GrenadeLocationsKv.GoBack();

    char newInfo[GRENADE_ID_LENGTH + AUTH_LENGTH + 1];
    Format(newInfo, sizeof(newInfo), "%s-%s", auth, idStr);
    g_newGrenades.PushString(newInfo);
    return nadeId;
}

public bool DeleteGrenadeFromKv(int client, const char[] nadeIdStr) {
    g_UpdatedGrenadeKv = true;
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
    bool deleted = false;
    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        char name[GRENADE_NAME_LENGTH];
        if (g_GrenadeLocationsKv.JumpToKey(nadeIdStr)) {
            g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
            g_GrenadeLocationsKv.GoBack();
        }

        deleted = g_GrenadeLocationsKv.DeleteKey(nadeIdStr);
        g_GrenadeLocationsKv.GoBack();
        PM_Message(client, "Deleted grenade id %s, \"%s\".", nadeIdStr, name);
    }
    return deleted;
}

public bool FindTargetNameByAuth(const char[] inputAuth, char[] name, int nameLen) {
    if (g_GrenadeLocationsKv.JumpToKey(inputAuth, false)) {
        g_GrenadeLocationsKv.GetString("name", name, nameLen);
        g_GrenadeLocationsKv.GoBack();
        return true;
    }
    return false;
}

public bool FindTargetInGrenadesKvByName(const char[] inputName, char[] name, int nameLen, char[] auth, int authLen) {
    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
            g_GrenadeLocationsKv.GetSectionName(auth, authLen);
            g_GrenadeLocationsKv.GetString("name", name, nameLen);

            if (StrContains(name, inputName, false) != -1) {
                g_GrenadeLocationsKv.GoBack();
                return true;
            }

        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
    }
    return false;
}

public void SetGrenadeData(int client, int index, const char[] key, const char[] value) {
    g_UpdatedGrenadeKv = true;
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
    char nadeId[GRENADE_ID_LENGTH];
    IntToString(index, nadeId, sizeof(nadeId));

    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        if (g_GrenadeLocationsKv.JumpToKey(nadeId)) {
            g_GrenadeLocationsKv.SetString(key, value);
            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }
}

public void GetGrenadeData(int client, int index, const char[] key, char[] value, int valueLength) {
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
    char nadeId[GRENADE_ID_LENGTH];
    IntToString(index, nadeId, sizeof(nadeId));

    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        if (g_GrenadeLocationsKv.JumpToKey(nadeId)) {
            g_GrenadeLocationsKv.GetString(key, value, valueLength);
            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }
}

public void UpdateGrenadeName(int client, int index, const char[] name) {
    SetGrenadeData(client, index, "name", name);
}

public void UpdateGrenadeDescription(int client, int index, const char[] description) {
    SetGrenadeData(client, index, "description", description);
}

public void AddGrenadeCategory(int client, int index, const char[] category) {
    char categoryString[GRENADE_CATEGORY_LENGTH];
    GetGrenadeData(client, index, "categories", categoryString, sizeof(categoryString));

    StrCat(categoryString, sizeof(categoryString), category);
    StrCat(categoryString, sizeof(categoryString), ";");
    SetGrenadeData(client, index, "categories", categoryString);

    CheckNewCategory(category);
}

public bool RemoveGrenadeCategory(int client, int index, const char[] category) {
    char categoryString[GRENADE_CATEGORY_LENGTH];
    GetGrenadeData(client, index, "categories", categoryString, sizeof(categoryString));

    char removeString[GRENADE_CATEGORY_LENGTH];
    Format(removeString, sizeof(removeString), "%s;", category);

    int numreplaced = ReplaceString(categoryString, sizeof(categoryString), removeString, "");
    SetGrenadeData(client, index, "categories", categoryString);
    return numreplaced > 0;
}

public bool FindGrenadeTarget(const char[] nameInput, char[] name, int nameLen, char[] auth, int authLen) {
    int target = AttemptFindTarget(nameInput);
    if (IsPlayer(target) && GetClientAuthId(target, AUTH_METHOD, auth, authLen) && GetClientName(target, name, nameLen)) {
        return true;
    } else {
        return FindTargetInGrenadesKvByName(nameInput, name, nameLen, auth, authLen);
    }
}

public bool FindGrenadeByName(const char[] auth, const char[] lookupName, char grenadeId[GRENADE_ID_LENGTH]) {
    char name[GRENADE_NAME_LENGTH];
    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
            do {
                g_GrenadeLocationsKv.GetSectionName(grenadeId, sizeof(grenadeId));
                g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
                if (StrEqual(name, lookupName)) {
                    g_GrenadeLocationsKv.GoBack();
                    g_GrenadeLocationsKv.GoBack();
                    return true;
                }
            } while (g_GrenadeLocationsKv.GotoNextKey());

            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }
    return false;
}

public int CountGrenadesForPlayer(const char[] auth) {
    int count = 0;
    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
            do {
                count++;
            } while (g_GrenadeLocationsKv.GotoNextKey());

            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }
    return count;
}

public void FindGrenadeCategories() {
    IterateGrenades(_FindGrenadeCategories_Helper);
}

public Action _FindGrenadeCategories_Helper(const char[] ownerName,
    const char[] ownerAuth, const char[] name,
    const char[] description, ArrayList cats,
    const char[] grenadeId,
    const float origin[3], const float angles[3], any data) {

    for (int i = 0; i < cats.Length; i++) {
        char cat[64];
        cats.GetString(i, cat, sizeof(cat));
        CheckNewCategory(cat);
    }
    return Plugin_Continue;
}

public void CheckNewCategory(const char[] cat) {
    if (!StrEqual(cat, "") && g_KnownNadeCategories.FindString(cat) == -1) {
        g_KnownNadeCategories.PushString(cat);
    }
}

public int AddCategoriesToList(const char[] categoryString, ArrayList list) {
    const int maxCats = 10;
    const int catSize = 64;
    char parts[maxCats][catSize];
    int foundCats = ExplodeString(categoryString, ";", parts, maxCats, catSize);
    for (int i = 0; i < foundCats; i++) {
        if (!StrEqual(parts[i], ""))
            list.PushString(parts[i]);
    }
    return foundCats;
}

public void TranslateGrenades(float dx, float dy, float dz) {
    DataPack p = CreateDataPack();
    p.WriteFloat(dx);
    p.WriteFloat(dy);
    p.WriteFloat(dz);
    g_UpdatedGrenadeKv = true;
    IterateGrenades(TranslateGrenadeHelper, p);
    delete p;
}

public Action TranslateGrenadeHelper(const char[] ownerName,
    const char[] ownerAuth, const char[] name,
    const char[] description, ArrayList categories,
    const char[] grenadeId,
    float origin[3], float angles[3],
    any data) {
    DataPack p = view_as<DataPack>(data);
    p.Reset();
    float dx = p.ReadFloat();
    float dy = p.ReadFloat();
    float dz = p.ReadFloat();
    origin[0] += dx;
    origin[1] += dy;
    origin[2] += dz;
}

public void NormalizeCategory(char[] category) {
    if (strlen(category) == 1) {
        UpperString(category);
    }  else {
        LowerString(category);
    }
}

public int FindNextGrenadeId(int client, int currentId) {
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));

    int ret = -1;
    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
            do {
                char idBuffer[GRENADE_ID_LENGTH];
                g_GrenadeLocationsKv.GetSectionName(idBuffer, sizeof(idBuffer));
                int id = StringToInt(idBuffer);
                if (id > currentId) {
                    ret = id;
                    break;
                }
            } while(g_GrenadeLocationsKv.GotoNextKey());
            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }

    return ret;
}
