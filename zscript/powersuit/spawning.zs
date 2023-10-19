const HDLD_SUITBEACON = "pst";

// Struct for itemspawn information.
class PowersuitSpawnItem play {

    // ID by string for spawner
    string spawnName;
    
    // ID by string for spawnees
    Array<PowersuitSpawnItemEntry> spawnReplaces;
    
    // Whether or not to persistently spawn.
    bool isPersistent;
    
    // Whether or not to replace the original item.
    bool replaceItem;

    string toString() {

        let replacements = "[";

        foreach (spawnReplace : spawnReplaces) replacements = replacements..", "..spawnReplace.toString();

        replacements = replacements.."]";

        return String.format("{ spawnName=%s, spawnReplaces=%s, isPersistent=%b, replaceItem=%b }", spawnName, replacements, isPersistent, replaceItem);
    }
}

class PowersuitSpawnItemEntry play {

    string name;
    int    chance;

    string toString() {
        return String.format("{ name=%s, chance=%s }", name, chance >= 0 ? "1/"..(chance + 1) : "never");
    }
}

// Struct for passing useinformation to ammunition.
class PowersuitSpawnAmmo play {

    // ID by string for the header ammo.
    string ammoName;
    
    // ID by string for weapons using that ammo.
    Array<string> weaponNames;
    
    string toString() {

        let weapons = "[";

        foreach (weaponName : weaponNames) weapons = weapons..", "..weaponName;

        weapons = weapons.."]";

        return String.format("{ ammoName=%s, weaponNames=%s }", ammoName, weapons);
    }
}

class hdpowersuitstorage
{
	int integrity;
	int armordurability;
	int batteries[3];
	int repairparts;
	
	string leftarmtype, rightarmtype, leftextra, rightextra;
	array<int> leftstatus, rightstatus;
}

class HDPowersuitSpawnHandler : EventHandler
{
	array<hdpowersuitstorage> suits;
	array<string> weapontypes;

	    // List of persistent classes to completely ignore.
    // This -should- mean this mod has no performance impact.
    static const string blacklist[] = {
        'HDSmoke',
        'BloodTrail',
        'CheckPuff',
        'WallChunk',
        'HDBulletPuff',
        'HDFireballTail',
        'ReverseImpBallTail',
        'HDSmokeChunk',
        'ShieldSpark',
        'HDFlameRed',
        'HDMasterBlood',
        'PlantBit',
        'HDBulletActor',
        'HDLadderSection'
    };

    // List of CVARs for Backpack Spawns
    array<Class <Inventory> > backpackBlacklist;

    // Cache of Ammo Box Loot Table
    private HDAmBoxList ammoBoxList;

    // List of weapon-ammo associations.
    // Used for ammo-use association on ammo spawn (happens very often).
    array<PowersuitSpawnAmmo> ammoSpawnList;

    // List of item-spawn associations.
    // used for item-replacement on mapload.
    array<PowersuitSpawnItem> itemSpawnList;

    bool cvarsAvailable;

    // appends an entry to itemSpawnList;
    void addItem(string name, Array<PowersuitSpawnItemEntry> replacees, bool persists, bool rep=true) {

        if (hd_debug) {

            let msg = "Adding "..(persists ? "Persistent" : "Non-Persistent").." Replacement Entry for "..name..": [";

            foreach (replacee : replacees) msg = msg..", "..replacee.toString();

            console.printf(msg.."]");
        }

        // Creates a new struct;
        PowersuitSpawnItem spawnee = PowersuitSpawnItem(new('PowersuitSpawnItem'));

        // Populates the struct with relevant information,
        spawnee.spawnName = name;
        spawnee.isPersistent = persists;
        spawnee.replaceItem = rep;
        spawnee.spawnReplaces.copy(replacees);

        // Pushes the finished struct to the array.
        itemSpawnList.push(spawnee);
    }

    PowersuitSpawnItemEntry addItemEntry(string name, int chance) {

        // Creates a new struct;
        PowersuitSpawnItemEntry spawnee = PowersuitSpawnItemEntry(new('PowersuitSpawnItemEntry'));
        spawnee.name = name;
        spawnee.chance = chance;
        return spawnee;
    }

    // appends an entry to ammoSpawnList;
    void addAmmo(string name, Array<string> weapons) {

        if (hd_debug) {
            let msg = "Adding Ammo Association Entry for "..name..": [";

            foreach (weapon : weapons) msg = msg..", "..weapon;

            console.printf(msg.."]");
        }

        // Creates a new struct;
        PowersuitSpawnAmmo spawnee = PowersuitSpawnAmmo(new('PowersuitSpawnAmmo'));
        spawnee.ammoName = name;
        spawnee.weaponNames.copy(weapons);

        // Pushes the finished struct to the array.
        ammoSpawnList.push(spawnee);
    }


    // Populates the replacement and association arrays.
    void init() {
        
        cvarsAvailable = true;
        
        //-----------------
        // Backpack Spawns
        //-----------------

		//if (!blackhawk_allowBackpacks)         backpackBlacklist.push((Class<Inventory>)('HDBlackhawk'));

        //------------
        // Ammunition
        //------------

        // 35mm
        Array<string> wep_35mm;
        wep_35mm.push('HDPowersuitBrontoArmPickup');
        addAmmo('BrontornisRound', wep_35mm);

		// Rocket Grenades
		Array<string> wep_gren;
		wep_gren.push('HDPowersuitRocketArmPickup');
		addAmmo('HDRocketAmmo', wep_gren);

		// 9mm
		Array<string> wep_9mm;
		wep_9mm.push('HDPowersuitSMGArmPickup');
		addAmmo('HD9mMag30', wep_9mm);
		addAmmo('HDPistolAmmo', wep_9mm);

		// 4mm
		Array<string> wep_4mm;
		wep_4mm.push('HDPowersuitVulcArmPickup');
		addAmmo('HD4mMag', wep_4mm);
		addAmmo('FourMilAmmo', wep_4mm);

		// 7mm
		Array<string> wep_7mm;
		wep_7mm.push('HDPowersuitLibArmPickup');
		addAmmo('HD7mMag', wep_7mm);
		addAmmo('SevenMilAmmo', wep_7mm);
		// Commented out as I actually dunno if this thing uses recasts. It shouldn't imo but whatever. - [Ted]
		//addAmmo ('SevenMilAmmoRecast', wep_7mm);

        // --------------------
        // Powersuit Spawns
        // --------------------

        // Full Powersuit spawner, replaces the original item
        Array<PowersuitSpawnItemEntry> spawns_full_powersuit_replace;
        spawns_full_powersuit_replace.push(addItemEntry('HDMegasphere', full_powersuit_megasphere_spawn_bias));
        spawns_full_powersuit_replace.push(addItemEntry('HDSoulsphere', full_powersuit_soulsphere_spawn_bias));
        spawns_full_powersuit_replace.push(addItemEntry('BFG9k', full_powersuit_BFG9k_spawn_bias));
        spawns_full_powersuit_replace.push(addItemEntry('HDRL', full_powersuit_rocketlauncher_spawn_bias));
		spawns_full_powersuit_replace.push(addItemEntry('ThunderBuster', full_powersuit_thunderbuster_spawn_bias));
        addItem('hdpowersuitspawnerpickup', spawns_full_powersuit_replace, full_powersuit_persistent_spawning);

		// Full Powersuit spawner, doesn't replace the original item
        Array<PowersuitSpawnItemEntry> spawns_full_powersuit_norep;
        spawns_full_powersuit_norep.push(addItemEntry('HDMegasphere', full_powersuit_norep_megasphere_spawn_bias));
        spawns_full_powersuit_norep.push(addItemEntry('HDSoulsphere', full_powersuit_norep_soulsphere_spawn_bias));
        spawns_full_powersuit_norep.push(addItemEntry('BFG9k', full_powersuit_norep_BFG9k_spawn_bias));
        spawns_full_powersuit_norep.push(addItemEntry('HDRL', full_powersuit_norep_rocketlauncher_spawn_bias));
		spawns_full_powersuit_norep.push(addItemEntry('ThunderBuster', full_powersuit_norep_thunderbuster_spawn_bias));
        addItem('hdpowersuitspawnerpickup', spawns_full_powersuit_norep, full_powersuit_norep_persistent_spawning, false);

        // Powersuit Beacon spawner, replaces the original item
        Array<PowersuitSpawnItemEntry> spawns_powersuit_beacon_replace;
        spawns_powersuit_beacon_replace.push(addItemEntry('HDMegasphere', powersuit_beacon_megasphere_spawn_bias));
        spawns_powersuit_beacon_replace.push(addItemEntry('HDSoulsphere', powersuit_beacon_soulsphere_spawn_bias));
        spawns_powersuit_beacon_replace.push(addItemEntry('BFG9k', powersuit_beacon_BFG9k_spawn_bias));
        spawns_powersuit_beacon_replace.push(addItemEntry('HDRL', powersuit_beacon_rocketlauncher_spawn_bias));
		spawns_powersuit_beacon_replace.push(addItemEntry('ThunderBuster', powersuit_beacon_thunderbuster_spawn_bias));
        addItem('hdpowersuitspawneractual', spawns_powersuit_beacon_replace, powersuit_beacon_persistent_spawning);

		// Powersuit Beacon spawner, doesn't replace the original item
        Array<PowersuitSpawnItemEntry> spawns_powersuit_beacon_norep;
        spawns_powersuit_beacon_norep.push(addItemEntry('HDMegasphere', powersuit_beacon_norep_megasphere_spawn_bias));
        spawns_powersuit_beacon_norep.push(addItemEntry('HDSoulsphere', powersuit_beacon_norep_soulsphere_spawn_bias));
        spawns_powersuit_beacon_norep.push(addItemEntry('BFG9k', powersuit_beacon_norep_BFG9k_spawn_bias));
        spawns_powersuit_beacon_norep.push(addItemEntry('HDRL', powersuit_beacon_norep_rocketlauncher_spawn_bias));
		spawns_powersuit_beacon_norep.push(addItemEntry('ThunderBuster', powersuit_beacon_norep_thunderbuster_spawn_bias));
        addItem('hdpowersuitspawneractual', spawns_powersuit_beacon_norep, powersuit_beacon_norep_persistent_spawning, false);

		// --------------------
        // Weapon Spawns
        // --------------------

		// Athena 35mm Cannon, replaces the original item
        Array<PowersuitSpawnItemEntry> spawns_athena_replaces;
        spawns_athena_replaces.push(addItemEntry('BFG9k', athena_replaces_BFG9k_spawn_bias));
        spawns_athena_replaces.push(addItemEntry('HDRL', athena_replaces_rocketlauncher_spawn_bias));
		spawns_athena_replaces.push(addItemEntry('ThunderBuster', athena_replaces_thunderbuster_spawn_bias));
        addItem('HDPowersuitBrontoArmPickup', spawns_athena_replaces, athena_replaces_persistent_spawning);

		// Athena 35mm Cannon, doesn't replace the original item
        Array<PowersuitSpawnItemEntry> spawns_athena_norep;
        spawns_athena_norep.push(addItemEntry('BFG9k', athena_norep_BFG9k_spawn_bias));
        spawns_athena_norep.push(addItemEntry('HDRL', athena_norep_rocketlauncher_spawn_bias));
		spawns_athena_norep.push(addItemEntry('ThunderBuster', athena_norep_thunderbuster_spawn_bias));
        addItem('HDPowersuitBrontoArmPickup', spawns_athena_norep, athena_norep_persistent_spawning, false);

		// Calinicus Automatic Grenade Launcher, replaces the original item
        Array<PowersuitSpawnItemEntry> spawns_calinicus_replaces;
        spawns_calinicus_replaces.push(addItemEntry('BFG9k', calinicus_replaces_BFG9k_spawn_bias));
        spawns_calinicus_replaces.push(addItemEntry('HDRL', calinicus_replaces_rocketlauncher_spawn_bias));
		spawns_calinicus_replaces.push(addItemEntry('ThunderBuster', calinicus_replaces_thunderbuster_spawn_bias));
        addItem('HDPowersuitRocketArmPickup', spawns_calinicus_replaces, calinicus_replaces_persistent_spawning);

		// Calinicus Automatic Grenade Launcher, doesn't replace the original item
        Array<PowersuitSpawnItemEntry> spawns_calinicus_norep;
        spawns_calinicus_norep.push(addItemEntry('BFG9k', calinicus_norep_BFG9k_spawn_bias));
        spawns_calinicus_norep.push(addItemEntry('HDRL', calinicus_norep_rocketlauncher_spawn_bias));
		spawns_calinicus_norep.push(addItemEntry('ThunderBuster', calinicus_norep_thunderbuster_spawn_bias));
        addItem('HDPowersuitRocketArmPickup', spawns_calinicus_norep, calinicus_norep_persistent_spawning, false);

		// Jackripper Hybrid Machine Gun, replaces the original item
        Array<PowersuitSpawnItemEntry> spawns_jackripper_replaces;
        spawns_jackripper_replaces.push(addItemEntry('BFG9k', jackripper_replaces_BFG9k_spawn_bias));
        spawns_jackripper_replaces.push(addItemEntry('HDRL', jackripper_replaces_rocketlauncher_spawn_bias));
		spawns_jackripper_replaces.push(addItemEntry('ThunderBuster', jackripper_replaces_thunderbuster_spawn_bias));
        addItem('HDPowersuitSMGArmPickup', spawns_jackripper_replaces, jackripper_replaces_persistent_spawning);

		// Jackripper Hybrid Machine Gun, doesn't replace the original item
        Array<PowersuitSpawnItemEntry> spawns_jackripper_norep;
        spawns_jackripper_norep.push(addItemEntry('BFG9k', jackripper_norep_BFG9k_spawn_bias));
        spawns_jackripper_norep.push(addItemEntry('HDRL', jackripper_norep_rocketlauncher_spawn_bias));
		spawns_jackripper_norep.push(addItemEntry('ThunderBuster', jackripper_norep_thunderbuster_spawn_bias));
        addItem('HDPowersuitSMGArmPickup', spawns_jackripper_norep, jackripper_norep_persistent_spawning, false);

		// Leonidas mounted light machine gun, replaces the original item
        Array<PowersuitSpawnItemEntry> spawns_leonidas_replaces;
        spawns_leonidas_replaces.push(addItemEntry('BFG9k', leonidas_replaces_BFG9k_spawn_bias));
        spawns_leonidas_replaces.push(addItemEntry('HDRL', leonidas_replaces_rocketlauncher_spawn_bias));
		spawns_leonidas_replaces.push(addItemEntry('ThunderBuster', leonidas_replaces_thunderbuster_spawn_bias));
        addItem('HDPowersuitVulcArmPickup', spawns_leonidas_replaces, leonidas_replaces_persistent_spawning);

		// Leonidas mounted light machine gun, doesn't replace the original item
        Array<PowersuitSpawnItemEntry> spawns_leonidas_norep;
        spawns_leonidas_norep.push(addItemEntry('BFG9k', leonidas_norep_BFG9k_spawn_bias));
        spawns_leonidas_norep.push(addItemEntry('HDRL', leonidas_norep_rocketlauncher_spawn_bias));
		spawns_leonidas_norep.push(addItemEntry('ThunderBuster', leonidas_norep_thunderbuster_spawn_bias));
        addItem('HDPowersuitVulcArmPickup', spawns_leonidas_norep, leonidas_norep_persistent_spawning, false);

		// ZMG33 mounted light machine gun, replaces the original item
        Array<PowersuitSpawnItemEntry> spawns_zmg33_replaces;
        spawns_zmg33_replaces.push(addItemEntry('BFG9k', zmg33_replaces_BFG9k_spawn_bias));
        spawns_zmg33_replaces.push(addItemEntry('HDRL', zmg33_replaces_rocketlauncher_spawn_bias));
		spawns_zmg33_replaces.push(addItemEntry('ThunderBuster', zmg33_replaces_thunderbuster_spawn_bias));
        addItem('HDPowersuitLibArmPickup', spawns_zmg33_replaces, zmg33_replaces_persistent_spawning);

		// ZMG33 mounted light machine gun, doesn't replace the original item
        Array<PowersuitSpawnItemEntry> spawns_zmg33_norep;
        spawns_zmg33_norep.push(addItemEntry('BFG9k', zmg33_norep_BFG9k_spawn_bias));
        spawns_zmg33_norep.push(addItemEntry('HDRL', zmg33_norep_rocketlauncher_spawn_bias));
		spawns_zmg33_norep.push(addItemEntry('ThunderBuster', zmg33_norep_thunderbuster_spawn_bias));
        addItem('HDPowersuitLibArmPickup', spawns_zmg33_norep, zmg33_norep_persistent_spawning, false);
    }

    // Random stuff, stores it and forces negative values just to be 0.
    bool giveRandom(int chance) {
        if (chance > -1) {
            let result = random(0, chance);

            if (hd_debug) console.printf("Rolled a "..(result + 1).." out of "..(chance + 1));

            return result == 0;
        }

        return false;
    }

    // Tries to create the item via random spawning.
    bool tryCreateItem(Actor thing, string spawnName, int chance, bool rep) {
        if (giveRandom(chance)) {
            if (Actor.Spawn(spawnName, thing.pos) && rep) {
                if (hd_debug) console.printf(thing.getClassName().." -> "..spawnName);

                thing.destroy();

                return true;
            }
        }

        return false;
    }
	
	// Deprecated by something to be deprecated again by something coolerer. Hopefully. - [Ted the Ted]
	/*override void checkreplacement(replaceevent e)
	{
		if (!e.replacement)
		{
			return;
		}
		
		if (e.replacement == "hdmegasphere" && random(0, 100) < 30)
		{
			e.replacement = "hdpowersuitspawnerpickup";
		}
	}*/
	
	override void worldthingspawned(worldevent e)
	{
        // If thing spawned doesn't exist, quit
        if (!e.thing) return;

        // If thing spawned is blacklisted, quit
        foreach (bl : blacklist) if (e.thing is bl) return;

        string candidateName = e.thing.getClassName();

        // Pointers for specific classes.
        let ammo = HDAmmo(e.thing);

        // If the thing spawned is an ammunition, add any and all items that can use this.
        if (ammo) handleAmmoUses(ammo, candidateName);

        // Return if range before replacing things.
        //if (level.MapName == 'RANGE') return;

        if (e.thing is 'HDAmBox') {
            handleAmmoBoxLootTable();
        } else {
            handleWeaponReplacements(e.thing, ammo, candidateName);
        }

		if (e.thing && e.thing.getclassname() == "hdpowersuitspawnerpickup" && !(hdpowersuitspawnerpickup(e.thing).owner))
		{
			hdpowersuitarmpickup(e.thing.spawn(weapontypes[random(0, weapontypes.size() - 1)], 
				e.thing.pos + (frandom(-16, 16), frandom(-16, 16), 0))).initializewepstats();
				
			hdpowersuitarmpickup(e.thing.spawn("hdpowersuitvulcarmpickup", 
				e.thing.pos + (frandom(-16, 16), frandom(-16, 16), 0))).initializewepstats();
		}
	}
	
	override void worldunloaded(worldevent e)
	{
		suits.clear();
		
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			playerinfo p = players[i];
			
			hdpowersuitstorage blanksuit = new("hdpowersuitstorage");
			suits.push(blanksuit);
			if (p && p.mo && p.readyweapon is "hdpowersuitinterface")
			{
				hdpowersuit suit = hdpowersuitinterface(p.mo.findinventory("hdpowersuitinterface")).suitcore;
				
				if (suit)
				{
					suits[i].integrity = suit.integrity;
					suits[i].armordurability = suit.suitarmor.durability;
					suits[i].batteries[0] = suit.batteries[0];
					suits[i].batteries[1] = suit.batteries[1];
					suits[i].batteries[2] = suit.batteries[2];
					suits[i].repairparts = suit.repairparts;
					
					suits[i].leftarmtype = suit.torso.leftarm.droppeditemname;
					suits[i].rightarmtype = suit.torso.rightarm.droppeditemname;
					suits[i].leftextra = suit.torso.leftarm.getextradata();
					suits[i].rightextra = suit.torso.rightarm.getextradata();
					
					suits[i].leftstatus.resize(HDWEP_STATUSSLOTS);
					suits[i].rightstatus.resize(HDWEP_STATUSSLOTS);
					suit.torso.leftarm.spawndroppedarm(suits[i].leftstatus);
					suit.torso.rightarm.spawndroppedarm(suits[i].rightstatus);
				}
			}
		}
	}

    private void handleAmmoBoxLootTable() {
        if (!ammoBoxList) {
            ammoBoxList = HDAmBoxList.Get();

            foreach (bl : backpackBlacklist) {
                let index = ammoBoxList.invClasses.find(bl.getClassName());

                if (index != ammoBoxList.invClasses.Size()) {
                    if (hd_debug) console.printf("Removing "..bl.getClassName().." from Ammo Box Loot Table");

                    ammoBoxList.invClasses.Delete(index);
                }
            }
        }
    }

    private void handleAmmoUses(HDAmmo ammo, string candidateName) {
        foreach (ammoSpawn : ammoSpawnList) if (candidateName ~== ammoSpawn.ammoName) {
            if (hd_debug) {
                console.printf("Adding the following to the list of items that use "..ammo.getClassName().."");
                foreach (weapon : ammoSpawn.weaponNames) console.printf("* "..weapon);
            }

            ammo.itemsThatUseThis.append(ammoSpawn.weaponNames);
        }
    }

    private void handleWeaponReplacements(Actor thing, HDAmmo ammo, string candidateName) {

        // Checks if the level has been loaded more than 1 tic.
        bool prespawn = !(level.maptime > 1);

        // Iterates through the list of item candidates for e.thing.
        foreach (itemSpawn : itemSpawnList) {

            // if an item is owned or is an ammo (doesn't retain owner ptr),
            // do not replace it.
            let item = Inventory(thing);
            if ((prespawn || itemSpawn.isPersistent) && (!(item && item.owner) && (!ammo || prespawn))) {
                foreach (spawnReplace : itemSpawn.spawnReplaces) {
                    if (spawnReplace.name ~== candidateName) {
                        if (hd_debug) console.printf("Attempting to replace "..candidateName.." with "..itemSpawn.spawnName.."...");

                        if (tryCreateItem(thing, itemSpawn.spawnName, spawnReplace.chance, itemSpawn.replaceItem)) return;
                    }
                }
            }
        }
    }
	
	override void worldloaded(worldevent e)
	{
		// Populates the main arrays if they haven't been already. 
        if (!cvarsAvailable) init();

        foreach (bl : backpackBlacklist) {
            if (hd_debug) console.printf("Removing "..bl.getClassName().." from Backpack Spawn Pool");
                
            BPSpawnPool.removeItem(bl);
		}

		for (int i = 0; i < allactorclasses.size(); i++)
		{
			if (allactorclasses[i] is "hdpowersuitarmpickup"
				&& !(allactorclasses[i].getclassname() == "hdpowersuitarmpickup"
				|| allactorclasses[i].getclassname() == "hdpowersuitblankarmpickup"))
			{
				weapontypes.push(allactorclasses[i].getclassname());
			}
		}
		
		if (!e.issavegame)
		{
			for (int i = 0; i < MAXPLAYERS; i++)
			{
				playerinfo p = players[i];
				
				if (p && p.mo && p.readyweapon is "hdpowersuitinterface")
				{
					if (!hdpowersuitinterface(p.readyweapon).suitcore)
					{
						hdpowersuit suit = hdpowersuit(p.mo.spawn("hdpowersuit", p.mo.pos));
						
						suit.driver = p.mo;
						suit.driver.bthruactors = true;
						suit.driver.player.cheats |= CF_FROZEN;
						suit.interface = hdpowersuitinterface(p.readyweapon);
						suit.interface.suitcore = suit;
						hdplayerpawn(suit.driver).tauntsound = "mech/horn";
						p.mo.a_setrenderstyle(1.0, STYLE_NONE);
						
						suit.torso.aimpoint = suit.spawn("hdpowersuitaimpoint", suit.pos);
						
						hdpowersuitarmpickup leftarmpickup, rightarmpickup;
						leftarmpickup = hdpowersuitarmpickup(suit.spawn(suits[i].leftarmtype, suit.pos));
						rightarmpickup = hdpowersuitarmpickup(suit.spawn(suits[i].rightarmtype, suit.pos));
						
						for (int j = 0; j < HDWEP_STATUSSLOTS; j++)
						{
							leftarmpickup.weaponstatus[j] = suits[i].leftstatus[j];
							rightarmpickup.weaponstatus[j] = suits[i].rightstatus[j];
						}
						
						hdpowersuitarm newleftarm = hdpowersuitarm(suit.spawn(leftarmpickup.armtype, suit.torso.leftarm.pos));
						hdpowersuitarm newrightarm = hdpowersuitarm(suit.spawn(rightarmpickup.armtype, suit.torso.rightarm.pos));
													
						newleftarm.isleft = true;
						newrightarm.isleft = false;
						newleftarm.handlemountammo(leftarmpickup, playerpawn(p.mo), false, true, suits[i].leftextra);
						newrightarm.handlemountammo(rightarmpickup, playerpawn(p.mo), false, true, suits[i].rightextra);
						newleftarm.suitcore = suit;
						newrightarm.suitcore = suit;
						
						suit.integrity = suits[i].integrity;
						suit.suitarmor.durability = suits[i].armordurability;
						suit.batteries[0] = suits[i].batteries[0];
						suit.batteries[1] = suits[i].batteries[1];
						suit.batteries[2] = suits[i].batteries[2];
						suit.repairparts = suits[i].repairparts;
						
						suit.torso.leftarm.destroy();
						suit.torso.rightarm.destroy();
						suit.torso.leftarm = newleftarm;
						suit.torso.rightarm = newrightarm;
						
						if (!(suit.torso.leftarm is "hdpowersuitblankarm"))
						{
							suit.torso.leftarm.armpoint = hdpowersuitaimpoint(suit.spawn("hdpowersuitaimpoint", suit.pos));
							suit.torso.leftarm.armpoint.isarm = true;
							suit.torso.leftarm.armpoint.isleft = true;
							suit.torso.leftarm.armpoint.accuracy = i;
						}
						
						if (!(suit.torso.rightarm is "hdpowersuitblankarm"))
						{
							suit.torso.rightarm.armpoint = hdpowersuitaimpoint(suit.spawn("hdpowersuitaimpoint", suit.pos));
							suit.torso.rightarm.armpoint.isarm = true;
							suit.torso.rightarm.armpoint.isleft = false;
							suit.torso.rightarm.armpoint.accuracy = i;
						}
						
						suit.viewz = suit.driver.player.viewz;
						
						suit.torso.translation = suit.driver.translation;
						suit.torso.leftleg.translation = suit.driver.translation;
						suit.torso.rightleg.translation = suit.driver.translation;
						
						leftarmpickup.destroy();
						rightarmpickup.destroy();
					}
				}
			}
		}
	}
}

class hdpowersuitspawnerpickup : hdpickup
{	
	default
	{
		inventory.pickupmessage "Picked up a powersuit warp-in beacon.";
		inventory.maxamount 1;
		hdpickup.refid HDLD_SUITBEACON;
		-hdpickup.fitsinbackpack;
		tag "Powersuit beacon";
	}
	
	states
	{
		spawn:
			HCAP A -1;
			stop;
			
		use:
			TNT1 A 0
			{			
				actor spawner = spawn("hdpowersuitspawneractual", pos);
				spawner.angle = angle;
				spawner.a_changevelocity(5, 0, 3, CVF_RELATIVE);
				spawner.translation = translation;
			}
			stop;
	}
}

class hdpowersuitspawneractual : actor
{
	default
	{
		radius 4;
		height 12;
	}
	
	states
	{
		spawn:
			HCAP AAA 35 nodelay
			{
				a_startsound("mech/beaconbeep", CHAN_BODY);
			}
			HCAP A 0
			{
				hdpowersuit suit = hdpowersuit(spawn("hdpowersuit", pos));
				
				suit.spawn("telefog", suit.pos);
				suit.targetangle = angle;
				suit.angle = angle;
				suit.torso.angle = angle;
		
				suit.integrity = suit.maxintegrity;
				suit.batteries[0] = 20;
				suit.batteries[1] = 20;
				suit.batteries[2] = -1;
				suit.suitarmor.durability = suit.maxarmor;
				
				hdpowersuitarm newleftarm = hdpowersuitarm(spawn("hdpowersuitblankarm", suit.pos));
				hdpowersuitarm newrightarm = hdpowersuitarm(spawn("hdpowersuitblankarm",  suit.pos));
													
				newleftarm.isleft = true;		
				newrightarm.isleft = false;
				newleftarm.suitcore = suit;
				newrightarm.suitcore = suit;
				
				suit.torso.leftarm.destroy();
				suit.torso.rightarm.destroy();
				suit.torso.leftarm = newleftarm;
				suit.torso.rightarm = newrightarm;
				
				suit.torso.translation = translation;
				suit.torso.leftleg.translation = translation;
				suit.torso.rightleg.translation = translation;
			}
			stop;
	}
}