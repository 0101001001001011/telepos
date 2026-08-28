# TelePOS — Vision: AI, self-service and ROS 2 robotics

**None of this is built.** This is a catalogue of intent, not a feature list and
not a roadmap. Nothing below is implemented, scheduled or promised, and no item
here should be read as a commitment. For what the product actually does today,
see [FEATURES.md](FEATURES.md); for what is broken, see the project status
section of the [README](../README.md).

It is published because the shape of the destination explains several decisions
in the code that would otherwise look like over-engineering — the wire protocol,
the device abstraction, the fact that a terminal is a role rather than a
hardware class.

The platform this assumes: **ROS 2** as the robot bus, **Zenoh** as the
transport between sites and cloud, **QUIC/WebTransport** as the wire to
workstations, and **edge inference** on the till itself.

---

## 1. Self-checkout

- Self-checkout as a workstation role
- Customer scanning, item by item and in a stream
- Camera product recognition without a barcode
- Weight control of the bagging area
- Detection of item substitution on the scale
- Detection of unscanned items in the basket
- One operator supervising several self-checkouts from a single screen
- Operator call, by button and automatically
- Age verification from a document
- Age estimation by camera
- Cash acceptance by note and coin acceptor
- Automatic change dispensing
- Payment by card, QR, face and palm
- Bonus payment at self-checkout
- Printed or electronic receipt at the customer's choice
- Voice guidance through the purchase
- Multilingual interface at the customer's choice
- Express mode for a returning customer
- First-use help and a guided walkthrough
- Automatic lock on suspicious behaviour
- Unstaffed store during night hours
- Grab-and-go format with no checkout at all
- Whole-basket verification at an exit gate
- Remote shift opening on a self-checkout
- Remote operator assistance over video

## 2. Vision and sensors on the shop floor

- Shelf cameras and out-of-stock detection
- Detection of incorrect merchandising
- Price-label verification against the database
- Visitor counting and route reconstruction
- Heat maps of the floor
- Checkout queue as a measured quantity
- Queue-length forecasting and opening tills in advance
- Detection of spills, litter and obstacles
- Expiry control by camera and by tag
- Shelf stocktaking from a photograph
- Age and restricted-sale enforcement
- Theft and barcode-swap detection
- Uniform and kitchen-hygiene compliance
- Temperature sensors in refrigerated displays
- Humidity and air-quality sensors in the warehouse
- RFID gates at entry and exit
- RFID tags on high-value goods
- Electronic shelf labels, priced from the till

## 3. AI at the till and on the floor

- Cashier assistant, by voice and by prompt
- Cross-sell suggestion at the moment of sale
- Substitute suggestion for an out-of-stock item
- Product card filled in automatically from a photograph
- Automatic product categorisation
- Automatic recognition of a supplier delivery note
- Supplier receipt parsed from a photograph
- Assistant for accounting errors within a shift
- Explanation of stocktaking discrepancies
- Product questions answered for the customer
- Virtual advisor on a screen on the floor
- Advisor robot that answers and walks the customer to the shelf
- Product search by description rather than by name
- Customer product search by photograph
- Assistant for the country's fiscal requirements
- Automatic translation of product cards into the site's languages

## 4. AI in merchandise and money

- Demand forecast by product and site
- Demand forecast accounting for weather and events
- Automatic supplier ordering
- Automatic stock transfer between sites
- Optimisation of the minimum holding level
- Dynamic pricing
- Markdown as the expiry date approaches
- Personal pricing for a returning customer
- Assortment optimisation and dead-stock removal
- Forecast of write-offs and losses
- Revenue forecast by shift and by hour
- Staff scheduling against the forecast
- Anomaly detection in cash operations
- Detection of collusion between cashier and customer
- Customer scoring for credit sales
- Supplier scoring by failures and quality
- Automatic dish cost and margin
- Menu recommendations against warehouse stock

## 5. Robotics core on ROS 2

- ROS 2 as the single robot bus of a site
- Zenoh as the transport between site, network and cloud
- One description of the site: map, zones, nodes, gates
- Digital twin of the store and warehouse
- Scenario simulation before robots enter the floor
- Task planner for a robot fleet
- Job queue dispatcher from till to robots
- Shared map of obstacles and people
- One coordinate system for floor, warehouse and yard
- Navigation without floor markings
- Fleet control from a single console
- Robot telemetry into the till's journal
- Over-the-air robot firmware updates
- Charging stations and charge planning
- Automatic battery swap
- Emergency stop and safe zones
- Separation of human and robot zones by time
- Robots working the night shift
- Manual takeover by an operator
- Remote robot control over the site's wire
- Every robot action journalled as a document
- Permissions and roles for robots on equal terms with people

## 6. Shop-floor robots

- Stocktaking robot patrolling the shelves
- Floor sweeping and washing robot
- Shelf replenishment robot from the back room
- Merchandising robot
- Price-label replacement robot
- Robot escorting a customer to a product
- Trolley robot that follows the customer
- Basket and trolley collection robot
- Expiry-control robot
- Night-patrol security robot
- Room disinfection robot
- Robot retrieving goods from an inaccessible zone
- Mobile display that comes to the customer

## 7. Warehouse robotics

- Autonomous mobile robots across the warehouse
- Pallet robots and stackers
- Rack shuttles
- Robotic arm for piece picking
- Robotic order packing
- Automatic repacking and reweighing
- Receiving robot: unload, verify, put away
- Automatic put-away into cells
- FEFO picking by robot
- Automatic cell stocktaking
- Order sorting conveyor
- Robotic cold-store
- Automatic replenishment of the picking zone
- Waste and packaging removal robot
- Autonomous yard forklift
- Robotic loading into a vehicle

## 8. Parcel lockers

- Order collection locker at the store
- Returns intake locker
- Locker for handing equipment in for service
- Locker for collecting equipment after repair
- Locker for goods intake from a supplier
- Locker holding orders until a deadline
- Cells at different temperatures: chilled, frozen, ambient
- Locker for packaging and recyclables intake
- Cell opening by code, QR or face
- Payment at the locker on collection
- Photographic record of contents on deposit and collection
- Device diagnostics on service intake, inside the cell
- Weighing and dimensioning of contents
- Automatic contents inventory by camera
- Robotic loading of the locker from inside
- Drone-to-locker docking
- Ground-robot-to-locker docking
- Locker as the handover point between courier and customer
- A network of lockers away from the store
- Mobile locker on a van
- Alerts for overflow and removal of uncollected items

## 9. Drones

- Drone delivery to a locker
- Drone delivery to the customer's yard
- Drone transport between stores in a chain
- Drone urgent delivery of a missing item to the till
- Drone delivery of a spare part to service
- Drone removal of equipment from a locker to the service centre
- Drone stocktaking of warehouse racking
- Drone overflight of floor and shelves
- Drone perimeter and yard security
- Automatic landing pad
- Automatic drone battery swap
- Weather flight restrictions
- Route and corridor planning
- Flight clearance against air regulations
- Cargo tracking in flight
- Drone-to-robot handover without a human
- Drone return on customer refusal
- Drone as a communications relay between sites

## 10. Ground delivery

- Pavement courier robot
- Courier robot inside a residential complex
- Autonomous van between warehouse and store
- Autonomous rounds between lockers
- Robot docking with lifts and building doors
- Order tracking by the customer on a map
- Order handover by code on meeting
- Thermal box with temperature control in transit
- Return of a refused order to the site
- Multiple orders in one robot
- Transfer between robot and drone in transit

## 11. Robotic service and repair

- Equipment intake without a human, through a locker
- Automatic diagnostics of the received device
- Photo and video record of condition on intake
- Robot moving jobs around the workshop
- Robotic diagnostic bench
- Robotic soldering and module replacement
- Automatic spare-part selection by model
- Automatic part ordering on shortage
- Repair-time forecast
- Customer notification at every step
- Automatic release from a locker after payment
- Warranty claim handled without a member of staff
- Robot testing the device after repair
- Automatic packing and sealing

## 12. Restaurant and kitchen

- Cook robot on the line
- Robotic grill and fryer
- Takeaway order assembly robot
- Runner robot delivering dishes to tables
- Dish-clearing robot
- Dishwashing robot
- Automatic portioned ingredient dispensing
- Dish quality control by camera
- Automatic temperature control on the line
- Kitchen display driven by robots and people together
- Kitchen load forecast from bookings and footfall
- Automatic ingredient write-off on actual preparation
- Barista robot and bartender robot
- Order collection through a heated locker
- Drone delivery of a prepared dish
- Automatic ordering table with no waiter

## 13. The customer and their journey

- Order in the app, collect from a locker
- Voice ordering
- Ordering through a chatbot
- AI basket assembly from a shopping list
- Repeat of a previous purchase in one tap
- Personal offers from history
- Personal discounts assigned by a model
- Dynamic points for behaviour rather than for amount
- Loyalty cards in the phone and by biometrics
- Subscription to recurring delivery
- Automatic replenishment of household staples
- Menu planning and ordering groceries against it
- Order tracking across the whole chain
- Choice of collection: till, locker, drone, courier
- Return through a locker with no explanation at the till
- Quality rating and complaint handling by a model

## 14. Accounting, money and law in autonomous scenarios

- A fiscal receipt issued with no human involved
- Responsibility and a robot's signature on a document
- Shifts opened and closed automatically
- Cash collection by a safe robot
- Automatic cash reconciliation
- Drone and robot operations recorded as warehouse documents
- Traceability of marked goods through a locker
- Electronic waybills between robots and the warehouse
- Age restrictions on unattended release
- EAEU rules for unmanned delivery
- Cargo insurance and liability on loss
- An audit trail for every autonomous action

## 15. Data, models and infrastructure

- Inference on the till itself, without the cloud
- Models that keep working when the link drops
- Fine-tuning on the site's own data
- Federated learning across a store network
- Anonymisation of personal data before training
- Feature store for products and their appearance
- Model versioning and rollback
- Observability of model quality in production
- Explainability of model decisions to the owner
- Limits on what a model is allowed to decide alone
- One event map of the site for every subsystem
- One journal: till, robot, drone, locker
- Site simulator for training without risk
- Acceptance benches for robots before they enter the floor
- Predictive maintenance of equipment
- Automatic ordering of consumables for robots

## 16. Network of sites

- One console for the network: stores, warehouses, robots, drones
- Automatic redistribution of goods between sites
- Order balancing between lockers
- A shared drone fleet across several sites
- Shared use of warehouse robots
- Autonomous dark collection point with no staff
- Container store deployable in a day
- Mobile site on a van
- Franchise site under remote management
- One AI dispatcher for the network
