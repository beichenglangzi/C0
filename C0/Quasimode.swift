/*
 Copyright 2018 S
 
 This file is part of C0.
 
 C0 is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 C0 is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with C0.  If not, see <http://www.gnu.org/licenses/>.
 */

struct Quasimode {
    var modifierEventTypes: [AlgebraicEventType] {
        didSet { updateAllEventableTypes() }
    }
    var eventTypes: [AlgebraicEventType] {
        didSet { updateAllEventableTypes() }
    }
    
    private(set) var allEventTypes: [AlgebraicEventType]
    private mutating func updateAllEventableTypes() {
        allEventTypes = modifierEventTypes + eventTypes
    }
    
    init(modifier modifierEventTypes: [AlgebraicEventType] = [],
         _ eventTypes: [AlgebraicEventType]) {
        
        self.modifierEventTypes = modifierEventTypes
        self.eventTypes = eventTypes
        allEventTypes = modifierEventTypes + eventTypes
    }
    
    var displayText: Localization {
        let mets = modifierEventTypes
        let mt = mets.reduce(into: Localization()) { $0 += $0.isEmpty ? $1.name : " " + $1.name }
        let ets = eventTypes
        let t = ets.reduce(into: Localization()) { $0 += $0.isEmpty ? $1.name : " " + $1.name }
        return mt.isEmpty ? t : "[" + mt + "] " + t
    }
}
