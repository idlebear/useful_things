//
// Pending changes:
//  - get rid of the class -- it makes it awkward to work with and just ugly in general.  A simple function will do that takes the 
//  array of values and returns the resulting array of assignments
//
//  - Make the stored data type a generic, but that is going to require
//  some negotiation with the swift gods....
//


fileprivate
class Munkres {
    
    var dataArray: [[Double]] = [[]]
    let rows: Int
    let cols: Int
    var zeros: [[ZeroState]]
    var coveredRows: [Int]
    var coveredCols: [Int]
    let rotated: Bool
    
    var startingPathRow: Int = 0
    var startingPathCol: Int = 0
    
    enum InternalState {
        case ensmallen, stars, covers, prime, augment, minimize, done
    }
    
    enum ZeroState {
        case none, starred, prime
    }
    
    init( withData data: [[Double]] ) {
        
        let dataRows = data.count
        let dataCols = data[0].count
        
        if dataCols >= dataRows {
            dataArray = data
            cols = dataCols
            rows = dataRows
            rotated = false
        } else {
            rotated = true
            cols = dataRows
            rows = dataCols
            
            for col in 0..<cols {
                dataArray.append([])
                for row in 0..<rows {
                    dataArray[col].append(data[row][col])
                }
            }
        }
        
        zeros = Array<Array<ZeroState>>(repeating: Array<ZeroState>(repeating: .none, count: cols), count: rows)
        coveredCols = Array<Int>(repeating: 0, count: cols)
        coveredRows = Array<Int>(repeating: 0, count: rows)
    }
    
    /**
   
     Step 1: Ensmallen!
 
     Minimize each row by subtracting the value of the smallest item in that row from each 
     element in the row (resulting in at least one zero value)
 
     */
    func ensmallenEachRow() -> InternalState {
        // Step 1
        for row in 0..<rows {
            var smallest = dataArray[row][0]
            for col in 1..<cols {
                if dataArray[row][col] < smallest {
                    smallest = dataArray[row][col]
                }
            }
            for col in 0..<cols {
                dataArray[row][col] -= smallest
            }
        }
        return .stars
    }

    /** 
  
     Step 2: Stars
 
     For each uncovered row/column, mark the first zero found, cover that row and continue
 
     */
    func starTheZeros() -> InternalState {
        // Step 2
        for row in 0..<rows {
            for col in 0..<cols {
                if dataArray[row][col] == 0 && coveredRows[row] == 0 && coveredCols[col] == 0 {
                    zeros[row][col] = .starred
                    coveredCols[col] = 1
                    coveredRows[row] = 1
                }
            }
        }
        clearCovers()
        return .covers
    }
    
    // MARK: Step 3 support functions
    //--------------------------------------------------------
    func clearCovers() -> Void {
        for col in 0..<cols {
            coveredCols[col] = 0
        }
        for row in 0..<rows {
            coveredRows[row] = 0
        }
    }
    
    /**
     
     Step 3: Apply covers
     
     Cover each column containing a starred zero.  If there are the same number of columns covered as there
     are rows, the starred zeros represent the complete set of assignments.  Go to .done.   Otherwise, continue
     to step 4, prime.
     
     */
    func applyCovers() -> InternalState {
        for row in 0..<rows {
            for col in 0..<cols {
                if zeros[row][col] == .starred {
                    coveredCols[col] = 1
                }
            }
        }
        
        var coveredCount = 0
        for covered in coveredCols {
            if covered == 1 {
                coveredCount += 1
            }
        }
        if coveredCount == rows {
            return .done
        }
        return .prime
    }
    
    // MARK: Step 4 support functions
    //--------------------------------------------------------
    func findNextUncoveredZero() -> (Int,Int)? {
        for row in 0..<rows {
            for col in 0..<cols {
                if dataArray[row][col] == 0 && coveredCols[col] == 0 && coveredRows[row] == 0 {
                    return (row,col)
                }
            }
        }
        return nil
    }
    
    func find( zeroState state: ZeroState, inRow row: Int ) -> Int? {
        for col in 0..<cols {
            if zeros[row][col] == state {
                return col
            }
        }
        return nil
    }
    
    
    /**
     
     Step 4: Prime
     
     Find the first non-covered zero and prime it.  If there is no non-starred zero in this row,
     go to step 5, augmentation.  Otherwise, cover this row and uncover the column containing the
     starred zero.  Continue until there are no uncovered zeros left, then go to step 6, minimize.
     
     */
    func primeZeros() -> InternalState {
        while true {
            guard  let(row, col) = findNextUncoveredZero() else {
                return .minimize
            }
            
            zeros[row][col] = .prime
            if let col = find( zeroState: .starred, inRow: row) {
                coveredCols[col] = 0
                coveredRows[row] = 1
            } else {
                startingPathRow = row
                startingPathCol = col
                break
            }
        }
        return .augment
    }
    
    // MARK: Step 5 support functions
    //--------------------------------------------------------
    func find( zeroState state: ZeroState, inCol col: Int ) -> Int? {
        for row in 0..<rows {
            if zeros[row][col] == state {
                return row
            }
        }
        return nil
    }
    
    func augment( zeroPath path: [(Int,Int)] ) -> Void {
        for (row,col) in path {
            if zeros[row][col] == .starred {
                zeros[row][col] = .none
            } else {
                zeros[row][col] = .starred
            }
        }
    }
    
    func erasePrimes() -> Void {
        for row in 0..<rows {
            for col in 0..<cols {
                if zeros[row][col] == .prime {
                    zeros[row][col] = .none
                }
            }
        }
    }
    
    /**
     
     Step 5: Augmentation
     
     Construct a series of alternating primed and starred zeros as follows:
     
     Let Z0 represent the uncovered primed zero found in step 4.
     Let Z1 represent the starred zero in the same column as Z0 (if it exists)
     Let Z2 represent the primed zero in the row of Z1 (always exists)
     
     Continue until the series terminates at a primed zero that has no starred
     zero in its column.  Unstar each starred zero (Z1) of the series, star each
     primed zero (Z0) of the series, erase all primes and uncover all rows and
     columns.
     
     Return to step 3, covers.
     
     */
    func augmentation() -> InternalState {
        // Step 5
        var path:[(Int,Int)] = [(startingPathRow, startingPathCol)]
        
        while true {
            let col = path.last!.1
            if let row = find(zeroState: .starred, inCol: col) {
                path.append((row,col))
                
                if let col = find(zeroState: .prime, inRow: row) {
                    path.append((row,col))
                }
            } else {
                break
            }
        }
        augment(zeroPath: path)
        clearCovers()
        erasePrimes()
        return .covers
    }
    
    // MARK: Step 6 support functions
    //--------------------------------------------------------
    func findSmallestUncovered() -> Double {
        var minimum = Double.infinity
        for row in 0..<rows {
            for col in 0..<cols {
                if coveredCols[col] == 0 && coveredRows[row] == 0 {
                    if dataArray[row][col] < minimum {
                        minimum = dataArray[row][col]
                    }
                }
            }
        }
        return minimum
    }
    
    
    /**
     
     Step 6: Minimize
     
     Add the smallest uncovered value to each covered row, and subtrace it from every element
     in every uncovered column. Return to step 4, prime.
     
     */
    func minimize() -> InternalState {
        let minimumValue = findSmallestUncovered()
        for row in 0..<rows {
            for col in 0..<cols {
                if coveredRows[row] == 1 {
                    dataArray[row][col] += minimumValue
                }
                if coveredCols[col] == 0 {
                    dataArray[row][col] -= minimumValue
                }
            }
        }
        return .prime
    }
    
    func resolve() -> [(Int, Int)] {
        var nextState = InternalState.ensmallen
        munkresCycle: while true {
            switch nextState {
            case .ensmallen:
                nextState = ensmallenEachRow()
            case .stars:
                nextState = starTheZeros()
            case .covers:
                nextState = applyCovers()
            case .prime:
                nextState = primeZeros()
            case .augment:
                nextState = augmentation()
            case .minimize:
                nextState = minimize()
            case .done:
                break munkresCycle
            }
        }
        
        var result: [(Int,Int)] = []
        findZeros: for row in 0..<rows {
            for col in 0..<cols {
                if zeros[row][col] == .starred {
                    result.append(rotated ? (col,row) : (row, col))
                    continue findZeros
                }
            }
        }
        
        return result
    }
}

public func calculateMunkres( withData data: [[Double]] ) -> [(Int,Int)] {
    return Munkres(withData: data).resolve()
}


