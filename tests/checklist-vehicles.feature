# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_vehiclekeys — Vehicles

  @kora_vehiclekeys @checklist @checklist:kora_vehiclekeys:no-key-denied @cat:vehicles
  Scenario: Locking/starting without keys is denied
    """
    Checklist test: On a vehicle you have no key for, L shows no access and the engine will not start (RequireKeyToStart).
    """
    Given a "test_car" is spawned in front of me
    When I press the "L" key
    Then I should see a notification containing "You don't have keys to this vehicle."
    When I get in the vehicle
    And I turn the engine on
    Then the vehicle engine should be off

  @kora_vehiclekeys @checklist @checklist:kora_vehiclekeys:engine-toggle @cat:vehicles
  Scenario: Toggle engine (G / /engine)
    """
    Checklist test: Driver with keys presses G or types /engine to toggle engine; without keys/job access it is refused.
    """
    Given I am in the driver seat of a "test_car"
    And I have the keys to the vehicle
    And the vehicle engine is off
    When I press the "G" key
    Then the vehicle engine should be running
    When I run the command "/engine"
    Then the vehicle engine should be off
    When I manually: ask a Mod to remove my keys
    And I press the "G" key
    Then the vehicle engine should be off
    When I run the command "/engine"
    Then the vehicle engine should be off

  @kora_vehiclekeys @checklist @checklist:kora_vehiclekeys:admin-keys @cat:vehicles @needs:admin @manual
  Scenario: Admin /addkeys and /removekeys
    """
    Checklist test: As admin run /addkeys <id> <plate> and /removekeys <id> <plate>; target gains/loses keys; non-admins refused.
    """
    When I manually: as admin, run /addkeys <id> <plate> for a target player
    Then I confirm: the target player gains keys to that plate
    When I manually: as admin, run /removekeys <id> <plate> for the same player
    Then I confirm: the target player loses keys to that plate
    When I manually: as a non-admin, run /addkeys and /removekeys
    Then I confirm: the commands are refused

  @kora_vehiclekeys @checklist @checklist:kora_vehiclekeys:physical-key @cat:vehicles
  Scenario: Physical vehicle key item
    """
    Checklist test: If Config.PhysicalKey is enabled, a 'vehiclekey' item with matching plate metadata acts as a key (off by default).
    """
    Given a "test_car" is spawned in front of me
    When I manually: get a vehiclekey item whose plate metadata matches the car's plate
    Then I confirm: with the key item in my inventory I can lock and start the car (only applies when Config.PhysicalKey is enabled; otherwise mark Pass if nothing happens)

  @kora_vehiclekeys @checklist @checklist:kora_vehiclekeys:job-vehicles @cat:vehicles
  Scenario: Job vehicle access without key
    """
    Checklist test: If Config.JobVehicles lists models for your job (empty by default), on-duty players can lock/start them without a key.
    """
    Given I am on duty
    When I manually: get in a vehicle model listed in Config.JobVehicles for my job
    Then I confirm: I can lock and start it without a key (only applies when Config.JobVehicles lists models for my job; otherwise mark Pass if nothing happens)

  @kora_vehiclekeys @checklist @checklist:kora_vehiclekeys:spawned-vehicle-keys @cat:vehicles @needs:admin
  Scenario: Keys for admin/job-spawned vehicles
    """
    Checklist test: Spawn a car via /car or a job vehicle: you should automatically receive a temporary key (TrustedSetOwner) for it.
    """
    When I run the command "/car"
    And I manually: spawn a car via /car, or a job vehicle
    Then I confirm: I automatically received a temporary key for it
    When I press the "L" key
    Then the vehicle should be locked
    When I turn the engine on
    Then the vehicle engine should be running

  @kora_vehiclekeys @checklist @checklist:kora_vehiclekeys:legacy-lockpick-event @cat:vehicles
  Scenario: Stock lockpick event compatibility
    """
    Checklist test: Items lockpick/advancedlockpick use flows via kora_vehiclekeys:client:lockpickUsed / lockpicks:UseLockpick (other resources).
    """
    Given I have 1 "lockpick"
    And I have 1 "advancedlockpick"
    And a "test_car" is spawned in front of me
    And the vehicle is locked
    When I use the "lockpick"
    Then I confirm: the lockpick flow runs
    When I use the "advancedlockpick"
    Then I confirm: the lockpick flow runs
    When the F8 console should show no errors
