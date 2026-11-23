import '../models/disaster_protocol.dart';

List<DisasterGuide> getDefaultDisasterGuides() {
  return [
    const DisasterGuide(
      type: DisasterType.typhoon,
      overview:
          'The Philippines is struck by an average of 20 tropical cyclones each year. Preparation saves lives before landfall.',
      beforeSteps: [
        'Inspect and reinforce roof, walls, windows, and doors.',
        'Trim tall tree branches near power lines or roof structures.',
        'Charge power banks, mobile phones, flashlights, and emergency radios.',
        'Store at least 1 gallon of drinking water per person per day for 3-5 days.',
        'Review family evacuation routes to designated LGU evacuation centers.',
        'Anchor loose outdoor furniture, signs, and zinc sheets (yero).',
      ],
      duringSteps: [
        'Stay indoors and away from glass windows and sliding doors.',
        'Keep updated via battery-powered radio or offline alerts.',
        'If floodwaters begin to enter, turn off main electricity breakers.',
        'Never wade through floodwaters to avoid leptospirosis and electrocution.',
        'Do not go outside during the "eye" of the typhoon; strong winds will resume suddenly from the opposite direction.',
      ],
      afterSteps: [
        'Wait for official clearance from NDRRMC/LGU before returning home.',
        'Inspect your house for structural damage, gas leaks, and exposed live wires.',
        'Boil water for drinking or use purification tablets until tested safe.',
        'Clear standing water and debris to prevent dengue mosquito breeding.',
        'Document damage with photos for insurance or LGU relief claims.',
      ],
      essentialSupplies: [
        'Water containers & purification tablets',
        'Canned goods & dry biscuits',
        'Waterproof pouch with valid IDs & cash',
        'LED flashlight & spare batteries',
        'Battery-operated AM/FM radio',
        'First-aid kit & maintenance medications',
      ],
    ),
    const DisasterGuide(
      type: DisasterType.earthquake,
      overview:
          'Earthquakes occur without warning due to active fault systems across Metro Manila and nearby regions (such as the West Valley Fault System).',
      beforeSteps: [
        'Practice "Duck, Cover, and Hold" drills with all household members.',
        'Fasten heavy furniture, cupboards, and appliances securely to walls.',
        'Store breakable items and heavy objects on lower shelves.',
        'Identify safe spots in each room: under sturdy desks or interior door frames.',
        'Keep your Go-Bag placed near the main exit for rapid evacuation.',
      ],
      duringSteps: [
        'DUCK down onto your hands and knees immediately.',
        'COVER your head and neck beneath a sturdy table or desk.',
        'HOLD ON firmly until the shaking completely stops.',
        'If outdoors, move to an open area away from power lines, poles, and glass facades.',
        'If driving, pull over safely away from overpasses and stay inside the vehicle.',
        'Do NOT use elevators under any circumstances.',
      ],
      afterSteps: [
        'Expect aftershocks. Be prepared to Duck, Cover, and Hold again.',
        'Check yourself and family members for injuries and apply first aid.',
        'Check for gas leaks (smell of LPG), fires, and electrical wire damage.',
        'Evacuate the building calmly using stairs. Do not panic or push.',
        'If trapped under debris, use a whistle or tap rhythmically on pipes; avoid shouting to conserve oxygen and reduce dust inhalation.',
      ],
      essentialSupplies: [
        'Emergency whistle (loud signaling)',
        'Heavy-duty work gloves & sturdy shoes',
        'First-aid supplies (gauze, antiseptic, bandages)',
        'Dust masks / N95 masks',
        'Flashlight (do NOT use matches/lighters due to possible gas leaks)',
      ],
    ),
    const DisasterGuide(
      type: DisasterType.flood,
      overview:
          'Monsoon rains (Habagat), tropical cyclones, and river overflow cause severe flooding across low-lying Metro Manila communities.',
      beforeSteps: [
        'Elevate furniture, appliances, and valuables to upper floors.',
        'Seal important documents in waterproof zip bags.',
        'Clean drainage gutters and community canals to prevent clogging.',
        'Identify local high-ground evacuation shelters in your barangay.',
        'Pre-charge communication devices and power banks.',
      ],
      duringSteps: [
        'Turn off the main electrical switch / breaker before water touches outlets.',
        'Evacuate early if advised by barangay officials or if living in flood-prone zones.',
        'Do NOT walk or drive through moving floodwaters (just 6 inches of rushing water can sweep an adult off their feet).',
        'Wear protective boots if wading is unavoidable to protect against leptospirosis and sharp debris.',
      ],
      afterSteps: [
        'Do not turn electrical appliances back on until thoroughly inspected by an electrician.',
        'Disinfect all items and surfaces that came into contact with floodwaters.',
        'Discard perishable food and medications that touched contaminated water.',
        'Take prophylaxis medication (e.g. Doxycycline) if you had open wounds exposed to floodwater, as directed by health workers.',
      ],
      essentialSupplies: [
        'Emergency raincoats & rubber boots',
        'Waterproof dry bag for survival kit',
        'Drinking water (safe from flood contamination)',
        'Oral rehydration salts & antiseptics',
        'Waterproof LED headlamp or torch',
      ],
    ),
    const DisasterGuide(
      type: DisasterType.fire,
      overview:
          'Structural fires can spread within minutes in dense urban residential zones. Quick reaction and escape plans are vital.',
      beforeSteps: [
        'Install and test smoke alarms in key living areas.',
        'Keep a working ABC fire extinguisher in the kitchen area.',
        'Map out at least two escape exits for every bedroom and hallway.',
        'Do not octopus-plug appliances or leave phone chargers plugged in unattended.',
        'Keep matches, lighters, and LPG tanks secured and ventilated.',
      ],
      duringSteps: [
        'Crawl low under smoke: clean, breathable air stays within 1 to 2 feet of the floor.',
        'Feel doors with the back of your hand before opening. If hot, use your secondary exit.',
        'GET OUT AND STAY OUT! Never re-enter a burning house for possessions.',
        'If your clothes catch fire: STOP, DROP, AND ROLL immediately.',
        'Call BFP (Bureau of Fire Protection) or 911 once safely outside.',
      ],
      afterSteps: [
        'Proceed directly to your pre-agreed family assembly point.',
        'Report immediately to firefighters if anyone is missing or unaccounted for.',
        'Seek immediate medical care for burns and smoke inhalation.',
        'Do not re-enter the structure until certified safe by the Fire Marshal.',
      ],
      essentialSupplies: [
        'Smoke & dust filter masks',
        'Small fire blanket / heavy cotton towels',
        'Burn ointment / sterile burn dressings',
        'Pocket flashlight for smoke navigation',
        'Emergency whistle',
      ],
    ),
    const DisasterGuide(
      type: DisasterType.landslide,
      overview:
          'Heavy monsoon rains, typhoons, and earthquakes can trigger sudden landslides and debris flows along steep slopes, riverbanks, and hillside communities.',
      beforeSteps: [
        'Check PHIVOLCS / MGB geohazard maps to see if your barangay is near a landslide-prone slope.',
        'Watch for early warning signs: new cracks in walls or ground, leaning trees/poles, or doors/windows sticking.',
        'Keep drainage channels and gutters clear so rainwater does not saturate slopes behind your home.',
        'Plan at least two evacuation routes moving away from valleys, gullies, and steep embankments.',
      ],
      duringSteps: [
        'Evacuate immediately if you hear rumbling sounds, snapping trees, or see sudden muddy stream surges.',
        'Move quickly to higher, stable ground sideways out of the landslide path — never run straight downhill.',
        'If trapped indoors and unable to escape, curl into a tight ball and shield your head under sturdy furniture.',
        'Stay alert when driving near hillside roads; watch for falling rocks and collapsed pavement.',
      ],
      afterSteps: [
        'Stay away from the slide area — secondary landslides often occur hours after the initial collapse.',
        'Check for injured or trapped neighbors without entering unstable debris; call 911 or Barangay DRRMO.',
        'Watch for flooding caused by landslide debris blocking nearby creeks or drainage canals.',
        'Report broken utility lines, damaged roads, and structural cracks to local authorities before returning.',
      ],
      essentialSupplies: [
        'Emergency whistle (to signal rescuers if trapped)',
        'Sturdy closed-toe shoes & heavy work gloves',
        'High-lumen LED flashlight & spare batteries',
        'Dust / N95 masks & first-aid trauma kit',
        'Waterproof Go-Bag with drinking water & IDs',
      ],
    ),
    const DisasterGuide(
      type: DisasterType.volcanicEruption,
      overview:
          'Nearby volcanic eruptions (such as Taal or Pinatubo) can produce dangerous ashfall and hazardous air quality across Metro Manila.',
      beforeSteps: [
        'Know the danger zones and alert levels set by PHIVOLCS.',
        'Stockpile N95 / KN95 masks for all household members.',
        'Protect water tanks and rainwater harvesting systems from ash contamination.',
        'Ensure livestock and domestic pets have sheltered enclosures.',
      ],
      duringSteps: [
        'Wear N95 masks or damp cloth over nose and mouth when ash is present.',
        'Protect your eyes with goggles; avoid wearing contact lenses.',
        'Close all windows, doors, and fireplace dampers to keep ash out.',
        'Stay indoors unless mandatory evacuation is ordered by authorities.',
        'Turn off air conditioning and ventilation units drawing outside air.',
      ],
      afterSteps: [
        'Carefully sweep ash off roofs to prevent structural collapse (dry ash is heavy; wet ash is twice as heavy).',
        'Do not wash ash down gutters or storm drains as it forms cement-like blockages.',
        'Thoroughly wash vegetables and fruits before eating.',
        'Replace air filters in cars and home ventilation.',
      ],
      essentialSupplies: [
        'N95 particulate respirator masks',
        'Protective eye goggles',
        'Heavy plastic sheeting & duct tape',
        'Bottled drinking water (sealed)',
        'Eye drops / saline solution',
      ],
    ),
  ];
}
