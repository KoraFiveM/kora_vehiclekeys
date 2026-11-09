# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_vehiclekeys — game tests

  @kora_vehiclekeys @legacy:keys-starts @target:1 @needs:admin @manual
  Scenario: Resource starts cleanly
    """
    Needs a Mod or dev with server console access.
    1. Restart the server (or watch the console at server start).
    2. Look for kora_vehiclekeys in the console output.
    3. In game press F8 and look for red errors mentioning kora_vehiclekeys.
    Expect: kora_vehiclekeys starts with no errors or warnings in the server console or F8, and kora_admin starts after it.
    """
    When I manually: ask a Mod or dev to restart the server and watch the server console at start
    And I manually: look for kora_vehiclekeys in the server console output
    And the F8 console should show no errors
    Then I confirm: kora_vehiclekeys starts with no errors or warnings in the server console
    And I confirm: kora_admin starts after kora_vehiclekeys

  @kora_vehiclekeys @legacy:keys-admin-car @target:2 @needs:admin
  Scenario: Admin-spawned car comes with keys
    """
    Needs a Mod.
    1. Mod types /car adder (any car model works).
    2. Mod is placed in the driver seat.
    3. Drive off.
    Expect: the car spawns next to the Mod, they are warped into the driver seat and the engine starts and stays running. No "no keys" message.
    """
    When I run the command "/car adder"
    Then I should be in the driver seat
    And the vehicle engine should be running
    When I manually: drive off in the car
    Then I confirm: the car spawned next to me and I was warped into the driver seat
    And I confirm: the engine stays running and no "no keys" message appears

  @kora_vehiclekeys @legacy:keys-veh-for-player @target:2 @needs:admin
  Scenario: Mod spawns a car for a tester with /veh
    """
    Needs a Mod.
    1. Tester tells the Mod their server ID.
    2. Mod types /veh <tester id> sultan.
    3. Tester drives the car.
    Expect: tester is put in the driver seat of a new Sultan and gets a notification "You received a sultan and its keys". The engine runs and the tester can drive normally.
    """
    When I run the command "/id"
    And I manually: tell a Mod my server ID and ask them to type /veh with my ID and sultan
    Then I should be in a "sultan"
    And I should be in the driver seat
    And I should see a notification containing "You received a sultan and its keys"
    And the vehicle engine should be running
    When I manually: drive the car
    Then I confirm: I can drive normally

  @kora_vehiclekeys @legacy:keys-lock-unlock @target:2 @checklist @checklist:kora_vehiclekeys:toggle-lock-key @cat:vehicles
  Scenario: Lock and unlock your car with L
    """
    Needs a car you have keys for (ask a Mod for /veh).
    1. Get out and stand next to the car.
    2. Press L.
    3. Try to get in.
    4. Press L again and get in.
    Expect: first L shows "Vehicle locked." (title Vehicle Keys) and you cannot open the doors. Second L shows "Vehicle unlocked." and you can get in normally.
    Also checklist kora_vehiclekeys:toggle-lock-key (Lock/unlock nearest vehicle (L)): Press L near your vehicle (with keys): doors lock/unlock with fob chirp, light flash, notification; also /togglelocks.
    """
    Given a "test_car" is spawned in front of me with keys
    When I press the "L" key
    Then I should see a notification containing "Vehicle locked."
    And I should see a notification titled "Vehicle Keys"
    And the vehicle should be locked
    When I manually: try to open the car door
    Then I confirm: I cannot open the doors
    When I press the "L" key
    Then I should see a notification containing "Vehicle unlocked."
    And the vehicle should be unlocked
    When I get in the vehicle
    Then I should be in a vehicle

  @kora_vehiclekeys @legacy:keys-feedback @target:2 @checklist @checklist:kora_vehiclekeys:lock-feedback @cat:vehicles
  Scenario: Lock sound, lights and key-fob animation
    """
    Needs a car you have keys for.
    1. Stand a few metres from the car, on foot.
    2. Press L to lock, then L to unlock.
    3. Get in the car and press L twice.
    Expect: on foot you hear a key-fob chirp, your character does a short key-fob click animation and the car's indicators and headlights flash twice. Inside the car you get the chirp, flash and notification but no animation.
    Also checklist kora_vehiclekeys:lock-feedback (Lock feedback and fob animation): On foot, locking plays key-fob animation, flashes indicators and plays sound; in-vehicle skips animation.
    """
    Given a "test_car" is spawned in front of me with keys
    When I manually: stand a few metres from the car, on foot
    And I press the "L" key
    And I press the "L" key
    Then I confirm: I hear a key-fob chirp and my character does a short key-fob click animation
    And I confirm: the car's indicators and headlights flash twice
    When I get in the vehicle
    And I press the "L" key
    And I press the "L" key
    Then I confirm: inside the car I get the chirp and the flash
    And I should see a notification containing "Vehicle"
    And I confirm: my character does no key-fob animation inside the car

  @kora_vehiclekeys @legacy:keys-feedback-others @target:2 @needs:players:2
  Scenario: Other players see the lights flash
    """
    Needs 2 testers and a car Tester A has keys for.
    1. Tester B stands near the car, Tester A about 10 m away.
    2. Tester A presses L to lock and unlock.
    Expect: Tester B sees the indicators and headlights flash twice on each press. Tester B does NOT hear the chirp (only Tester A does) and gets no notification.
    """
    Given a "test_car" is spawned in front of me with keys
    When I manually: ask a second player to stand near the car
    And I manually: stand about 10 m away from the car
    And I press the "L" key
    And I press the "L" key
    Then I confirm: the other player sees the indicators and headlights flash twice on each press
    And I confirm: the other player does NOT hear the chirp and gets no notification
    And I confirm: I hear the chirp myself

  @kora_vehiclekeys @legacy:keys-range @target:2
  Scenario: Remote lock range
    """
    Needs a car you have keys for, parked away from other cars.
    1. Walk about 15 m away and press L.
    2. Walk 40 m or more away (nothing else parked near you) and press L.
    Expect: at 15 m the car locks/unlocks with the usual message and flash. At 40 m+ you get "No nearby networked vehicle." and nothing changes on the car.
    """
    Given a "test_car" is spawned in front of me with keys
    When I manually: walk about 15 m away from the car, away from other cars
    And I press the "L" key
    Then I should see a notification containing "Vehicle locked."
    And the vehicle should be locked
    And I confirm: the car flashes its lights
    When I manually: walk 40 m or more away from the car with nothing else parked near me
    And I press the "L" key
    Then I should see a notification containing "No nearby networked vehicle."
    And the vehicle should be locked
    And I confirm: nothing changes on the car

  @kora_vehiclekeys @legacy:keys-no-keys-lock @target:2 @needs:players:2
  Scenario: Cannot lock or unlock a car without keys
    """
    Needs 2 testers and a car Tester A has keys for.
    1. Tester A gets out and walks away.
    2. Tester B (no keys) stands next to the car and presses L.
    Expect: Tester B gets "You do not have the keys for this vehicle." The car does not lock or unlock, no chirp and no lights flash.
    """
    Given a "test_car" is spawned in front of me
    When I manually: ask a second player who has keys to this car to get out and walk away
    And I press the "L" key
    Then I confirm: I get "You do not have the keys for this vehicle."
    And I confirm: the car does not lock or unlock
    And I confirm: no chirp is heard and no lights flash

  @kora_vehiclekeys @legacy:keys-locked-others @target:2 @needs:players:2
  Scenario: Locked car stays locked for everyone
    """
    Needs 2 testers and a car Tester A has keys for.
    1. Tester A locks the car with L and walks away.
    2. Tester B tries to get into every door.
    3. Tester A unlocks it with L.
    4. Tester B tries again.
    Expect: while locked Tester B cannot get in (character pulls the handle or gives up). After unlock Tester B can get in.
    """
    Given a "test_car" is spawned in front of me with keys
    When I press the "L" key
    And I manually: walk away from the car
    And I manually: ask a second player to try to get into every door
    Then I confirm: the other player cannot get in (character pulls the handle or gives up)
    When I manually: walk back to the car
    And I press the "L" key
    And I manually: ask the second player to try to get in again
    Then I confirm: the other player can get in

  @kora_vehiclekeys @legacy:keys-no-keys-engine @target:2 @needs:players:2
  Scenario: Engine will not run without keys
    """
    Needs 2 testers and a car Tester A has keys for (unlocked).
    1. Tester A gets out and walks away.
    2. Tester B gets in the driver seat and tries to drive (hold accelerate, press G).
    Expect: the engine shuts off and will not start for Tester B, even if it was running. The car cannot be driven. G does nothing for Tester B.
    """
    Given a "test_car" is spawned in front of me
    And the vehicle is unlocked
    When I manually: ask a second player who has keys to this car to get out and walk away
    And I get in the vehicle
    And I manually: hold accelerate
    And I press the "G" key
    Then the vehicle engine should be off
    And I confirm: the car cannot be driven
    And I confirm: G does nothing for me

  @kora_vehiclekeys @legacy:keys-engine-g @target:2
  Scenario: Turn the engine on and off with G
    """
    Needs a car you have keys for.
    1. Sit in the driver seat with the engine running.
    2. Press G.
    3. Press G again.
    4. Type /engine in chat.
    Expect: first G turns the engine off, second G turns it back on. /engine toggles it the same way. Pressing G in a passenger seat or on foot does nothing.
    """
    Given I am in the driver seat of a "test_car"
    And I have the keys to the vehicle
    And the vehicle engine is running
    When I press the "G" key
    Then the vehicle engine should be off
    When I press the "G" key
    Then the vehicle engine should be running
    When I run the command "/engine"
    Then the vehicle engine should be off
    When I run the command "/engine"
    Then the vehicle engine should be running
    When I manually: press G in a passenger seat and on foot
    Then I confirm: pressing G in a passenger seat or on foot does nothing

  @kora_vehiclekeys @legacy:keys-commands @target:1
  Scenario: /togglelocks works like the L key
    """
    Needs a car you have keys for.
    1. Stand next to the car.
    2. Type /togglelocks in chat.
    3. Type /togglelocks again.
    Expect: the car locks then unlocks with the same "Vehicle locked." / "Vehicle unlocked." messages, chirp and light flash as pressing L.
    """
    Given a "test_car" is spawned in front of me with keys
    When I run the command "/togglelocks"
    Then I should see a notification containing "Vehicle locked."
    And the vehicle should be locked
    And I confirm: I hear the chirp and the car lights flash as with L
    When I run the command "/togglelocks"
    Then I should see a notification containing "Vehicle unlocked."
    And the vehicle should be unlocked
    And I confirm: I hear the chirp and the car lights flash as with L

  @kora_vehiclekeys @legacy:keys-passengers @target:2 @needs:players:2
  Scenario: Passengers in a car with keys
    """
    Needs 2 testers and a car Tester A has keys for.
    1. Tester A drives, Tester B sits in the passenger seat.
    2. Tester B presses L and G.
    3. Tester A stops and locks the car with L.
    4. Tester B gets out, then tries to get back in.
    Expect: Tester B's L shows "You do not have the keys for this vehicle." and G does nothing. Tester B can still get OUT of the locked car but cannot get back in.
    """
    Given I am in the driver seat of a "test_car"
    And I have the keys to the vehicle
    When I manually: ask a second player to sit in the passenger seat and drive a short way
    And I manually: ask the second player to press L and G
    Then I confirm: the other player sees "You do not have the keys for this vehicle." for L and nothing happens for G
    When I manually: stop the car
    And I press the "L" key
    And I manually: ask the second player to get out, then try to get back in
    Then I confirm: the other player can get OUT of the locked car
    And I confirm: the other player cannot get back in

  @kora_vehiclekeys @legacy:keys-givekeys @target:2 @needs:players:2 @checklist @checklist:kora_vehiclekeys:give-keys @cat:vehicles
  Scenario: Hand your keys to a nearby player with /givekeys
    """
    Needs 2 testers (neither a Mod) and a car Tester A has keys for.
    1. Tester B stands right next to Tester A.
    2. Tester A types /givekeys <Tester B's id>.
    3. Tester B presses L by the car, then drives it.
    Expect: Tester A sees "You hand over the keys.", Tester B sees "You get keys to the vehicle!" and can lock and drive the car. Report it if you get a permission error or nothing happens.
    Also checklist kora_vehiclekeys:give-keys (Give keys to another player (/givekeys)): Hold keys to a car, /givekeys [id] (or nearest/passengers within range) hands session keys; receiver can then lock/drive.
    """
    Given a "test_car" is spawned in front of me with keys
    When I manually: ask a second player (not a Mod) to stand right next to me
    And I manually: type /givekeys with the second player's ID
    Then I should see a notification containing "You hand over the keys."
    And I confirm: the other player sees "You get keys to the vehicle!"
    When I manually: ask the second player to press L by the car, then drive it
    Then I confirm: the other player can lock the car and drive it
    And I confirm: no permission error appears

  @kora_vehiclekeys @legacy:keys-mod-givekeys @target:2 @needs:admin @needs:players:2
  Scenario: Mod gives a tester keys to the car they are driving
    """
    Needs a Mod and 2 testers.
    1. Tester B sits in the driver seat of a car they have no keys for (engine keeps dying).
    2. Mod types /givekeys <Tester B's id>.
    3. Tester B drives off, then gets out and presses L.
    Expect: Tester B gets "You received keys to your current vehicle", the engine now runs and L locks the car.
    """
    Given I am in the driver seat of a "test_car"
    When I run the command "/id"
    And I manually: tell a Mod my server ID
    And I manually: check the engine keeps dying
    And I manually: ask the Mod to type /givekeys with my server ID
    Then I should see a notification containing "You received keys to your current vehicle"
    And the vehicle engine should be running
    When I manually: drive off
    And I get out of the vehicle
    And I press the "L" key
    Then I should see a notification containing "Vehicle locked."
    And the vehicle should be locked

  @kora_vehiclekeys @legacy:keys-addremove @target:2 @needs:admin
  Scenario: Admin /addkeys and /removekeys
    """
    Needs a Mod with admin access and a car with a plate you can read.
    1. Tester with no keys stands by the car.
    2. Mod types /addkeys <tester id> <plate>. Tester presses L.
    3. Mod types /removekeys <tester id> <plate>. Tester presses L.
    4. Mod types /addkeys with no arguments.
    Expect: after addkeys L works; after removekeys it shows "You do not have the keys for this vehicle.". No arguments shows "Fill out the player ID and Plate arguments".
    """
    Given a "test_car" is spawned in front of me
    When I manually: read the car's plate and tell a Mod my server ID and the plate
    And I manually: ask the Mod to type /addkeys with my ID and the plate
    And I press the "L" key
    Then I should see a notification containing "Vehicle locked."
    When I manually: ask the Mod to type /removekeys with my ID and the plate
    And I press the "L" key
    Then I confirm: I get "You do not have the keys for this vehicle."
    When I run the command "/addkeys"
    Then I should see a notification containing "Fill out the player ID and Plate arguments"

  @kora_vehiclekeys @legacy:keys-hotwire-nopick @target:1
  Scenario: Hotwire key without a lockpick
    """
    1. Take any NPC car (pull a driver out, or get into a parked one).
    2. Notice the engine cuts out.
    3. Make sure you have no lockpick, sit in the driver seat and press U.
    Expect: the engine will not stay on. Pressing U shows "You need a lockpick." (title Hotwire Failed) and nothing else happens.
    """
    Given I have no "lockpick"
    When I manually: take any NPC car (pull a driver out, or get into a parked one)
    Then I confirm: the engine cuts out
    When I manually: sit in the driver seat
    And I press the "U" key
    Then I should see a notification containing "You need a lockpick."
    And I should see a notification titled "Hotwire Failed"
    And I confirm: the engine will not stay on and nothing else happens

  @kora_vehiclekeys @legacy:keys-hotwire @target:2 @needs:admin @checklist @checklist:kora_vehiclekeys:hotwire @cat:vehicles
  Scenario: Hotwire an NPC car with a lockpick
    """
    Needs a Mod to give you a lockpick (/giveitem <id> lockpick 1).
    1. Get in the driver seat of an NPC car.
    2. Press U (or use the Lockpick from your inventory).
    3. Finish the lockpick minigame.
    4. Drive, then get out and press L.
    Expect: on success "Vehicle hotwired." (title Hotwire); the engine now runs and L locks/unlocks this car. Fail shows "The ignition resisted your lockpick.". The lockpick sometimes breaks ("Your lockpick broke.").
    Also checklist kora_vehiclekeys:hotwire (Hotwire vehicle (U)): Sit in driver seat of a keyless vehicle and press U: hotwire attempt, success grants a session key and allows ignition.
    """
    Given I have 1 "lockpick"
    When I manually: get in the driver seat of an NPC car
    And I press the "U" key
    And I manually: finish the lockpick minigame
    Then I confirm: on success I see "Vehicle hotwired." with title "Hotwire" and the engine runs
    And I confirm: on failure I see "The ignition resisted your lockpick."
    And I confirm: the lockpick sometimes breaks ("Your lockpick broke.")
    When I manually: drive, then get out of the car
    And I press the "L" key
    Then I confirm: L locks and unlocks this car

  @kora_vehiclekeys @legacy:keys-hotwire-notneeded @target:1
  Scenario: Lockpick not needed in a car you have keys for
    """
    Needs a car you have keys for and a lockpick.
    1. Sit in the driver seat, turn the engine off with G.
    2. Press U.
    3. Use the Lockpick from your inventory.
    Expect: U does nothing at all (no message, no minigame). Using the Lockpick item shows "You do not need a lockpick for this vehicle." and no minigame starts.
    """
    Given I am in the driver seat of a "test_car"
    And I have the keys to the vehicle
    And I have 1 "lockpick"
    When I press the "G" key
    Then the vehicle engine should be off
    When I press the "U" key
    Then I confirm: U does nothing at all (no message, no minigame)
    When I use the "lockpick"
    Then I should see a notification containing "You do not need a lockpick for this vehicle."
    And I confirm: no minigame starts

  @kora_vehiclekeys @legacy:keys-lockpick-door @target:2 @needs:players:2 @checklist @checklist:kora_vehiclekeys:lockpick-item @cat:vehicles
  Scenario: Lockpick a locked car door on foot
    """
    Needs 2 testers, a car Tester A has keys for, and a lockpick for Tester B (Mod /giveitem).
    1. Tester A locks the car and steps away.
    2. Tester B stands at the door and uses the Lockpick from the inventory.
    3. Finish the minigame, then get in and try to drive.
    Expect: success shows "You picked the door lock open." and the car unlocks, but the engine still will not run for Tester B. Fail shows "Lockpicking Failed" / "You failed to pick the lock.".
    Also checklist kora_vehiclekeys:lockpick-item (Lockpick a locked vehicle): Use lockpick/advancedlockpick item near a locked vehicle: lockpick minigame; success unlocks, picks can break (5%/25%).
    """
    Given I have 1 "lockpick"
    And a "test_car" is spawned in front of me
    And the vehicle is locked
    When I manually: ask a second player who has keys to lock the car and step away
    And I use the "lockpick"
    And I manually: finish the lockpick minigame
    Then I confirm: on success I see "You picked the door lock open." and the car unlocks
    And I confirm: on failure I see "Lockpicking Failed" / "You failed to pick the lock."
    When I get in the vehicle
    And I manually: try to drive
    Then I confirm: the engine still will not run for me

  @kora_vehiclekeys @legacy:keys-lockpick-errors @target:1 @checklist @checklist:kora_vehiclekeys:lockpick-messages @cat:vehicles
  Scenario: Lockpick on foot error messages
    """
    Needs a lockpick (Mod /giveitem) and a car you have keys for.
    1. Stand far from any car and use the Lockpick.
    2. Stand by an unlocked car you have no keys for and use it.
    3. Lock your own car, stand by it and use it.
    Expect: 1 shows "There is no vehicle close enough to lockpick.", 2 shows "This vehicle is not locked.", 3 shows "You already have the keys.". No minigame starts and the pick is not used up.
    Also checklist kora_vehiclekeys:lockpick-messages (Lockpick edge-case notices): Use a lockpick with no vehicle near or on an unlocked car: 'no vehicle close enough' / 'You do not need a lockpick'.
    """
    Given I have 1 "lockpick"
    And a "test_car" is spawned in front of me with keys
    When I manually: stand far from any car
    And I use the "lockpick"
    Then I should see a notification containing "There is no vehicle close enough to lockpick."
    And I should have 1 "lockpick"
    When I manually: stand by an unlocked car you have no keys for (ask a Mod to spawn one)
    And I use the "lockpick"
    Then I should see a notification containing "This vehicle is not locked."
    And I confirm: no minigame starts
    And I should have 1 "lockpick"
    When I lock the vehicle
    And I manually: stand by my own locked car
    And I use the "lockpick"
    Then I should see a notification containing "You already have the keys."
    And I confirm: no minigame starts
    And I should have 1 "lockpick"

  @kora_vehiclekeys @legacy:keys-bike @target:2 @needs:admin @needs:players:2 @checklist @checklist:kora_vehiclekeys:bike-lock @cat:vehicles @manual
  Scenario: Locked bike stays blocked for others
    """
    Needs a Mod and 2 testers.
    1. Mod spawns a bike for Tester A (/veh <A's id> bati).
    2. Tester A gets off, presses L to lock it and knocks it over (or leaves it standing).
    3. Tester B tries to get on it.
    4. Tester A tries to get on / lift it.
    Expect: Tester B is stopped or pushed off and sees "This bike is locked.". Tester A can lift and ride it while it is locked.
    Also checklist kora_vehiclekeys:bike-lock (Locked bikes cannot be picked up): Lock a bicycle/bike: others see 'This bike is locked.' when trying to lift it; key holder can pick it up.
    """
    When I manually: ask a Mod to spawn a bike for Tester A with /veh <A's id> bati
    And I manually: as Tester A, get off the bike, press L to lock it and knock it over or leave it standing
    And I manually: ask Tester B to try to get on the bike
    Then I confirm: Tester B is stopped or pushed off and sees "This bike is locked."
    When I manually: as Tester A, try to get on and lift the bike while it is locked
    Then I confirm: Tester A can lift and ride the bike while it is locked

  @kora_vehiclekeys @legacy:keys-relog @target:2
  Scenario: Keys after relogging
    """
    Needs a car you have keys for.
    1. Park the car, note where it is. Make sure it is unlocked.
    2. Disconnect and reconnect, pick the same character.
    3. Go back to the car (if it is still there), get in the driver seat, press L.
    Expect: keys only last for your session, so after relogging you no longer have them: the engine will not run and L shows "You do not have the keys for this vehicle.". Nothing errors.
    """
    Given a "test_car" is spawned in front of me with keys
    And the vehicle is unlocked
    When I manually: park the car and note where it is
    And I manually: disconnect, reconnect and pick the same character
    And I manually: go back to the car and get in the driver seat
    And I press the "L" key
    Then I should see a notification containing "You do not have the keys for this vehicle."
    And I confirm: the engine will not run
    When the F8 console should show no errors

  @kora_vehiclekeys @legacy:keys-restart @target:2 @needs:admin
  Scenario: Restarting kora_vehiclekeys
    """
    Do this when few players are on. kora_admin depends on kora_vehiclekeys, so a restart can stop them; if anything stays broken, a full server restart fixes it.
    Needs a Mod or dev with txAdmin, plus a tester in a car they have keys for.
    1. Lock the car with L.
    2. Dev restarts kora_vehiclekeys.
    3. Tester presses L, G and U, and checks F8.
    4. Mod tries /car adder.
    Expect: no errors in F8 or the server console. Keys are lost on restart (session only), so L says no keys and the car stays locked. kora_admin still works: /car spawns a car with working keys.
    """
    Given I am in the driver seat of a "test_car"
    And I have the keys to the vehicle
    When I lock the vehicle
    And I manually: ask a dev with txAdmin to restart kora_vehiclekeys
    And I press the "L" key
    And I press the "G" key
    And I press the "U" key
    And the F8 console should show no errors
    Then I confirm: the server console shows no errors
    And I confirm: L says no keys and the car stays locked
    And the vehicle should be locked
    When I manually: ask a Mod to try /car adder
    Then I confirm: /car spawns a car with working keys and kora_admin still works

  @kora_vehiclekeys @legacy:keys-spam @target:1
  Scenario: Spamming L does not break locking
    """
    Needs a car you have keys for.
    1. Stand by the car and press L very fast about 15 times.
    2. Wait 10 seconds.
    3. Press L once.
    Expect: some presses may be ignored, but the final single L still locks/unlocks with the normal message. Locking keeps working afterwards and no errors appear in F8.
    """
    Given a "test_car" is spawned in front of me with keys
    When I manually: stand by the car and press L very fast about 15 times
    And I wait 10 seconds
    And I press the "L" key
    Then I confirm: the final L locks or unlocks the car with the normal message
    And I confirm: locking keeps working afterwards
    When the F8 console should show no errors

  @kora_vehiclekeys @legacy:keys-resmon @target:1 @manual
  Scenario: Resource usage (resmon)
    """
    1. Press F8 and type resmon 1.
    2. Find kora_vehiclekeys.
    3. Watch it on foot for 30 seconds, then while driving a car you have keys for, then sitting in a car with no keys.
    Expect: kora_vehiclekeys stays very low (around 0.00 to 0.02 ms) in all three cases with no spikes. Note the highest number you saw.
    """
    When I manually: press F8 and type resmon 1
    And I manually: find kora_vehiclekeys in the list
    And I manually: watch it on foot for 30 seconds, then while driving a car I have keys for, then sitting in a car with no keys
    Then I confirm: kora_vehiclekeys stays around 0.00 to 0.02 ms in all three cases with no spikes
    And I confirm: I noted the highest number I saw
