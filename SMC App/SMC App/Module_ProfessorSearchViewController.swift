//
//  ProfessorSearchViewController.swift
//  SMC App
//
//  Created by Harrison Balogh on 5/14/15.
//  Copyright (c) 2015 CPC iOS. All rights reserved.
//

import UIKit
import CoreData
import Foundation

class Module_ProfessorSearchViewController: UIViewController {
    
    var finishedDataRetrieval: Bool! = false

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func reloadDataButton(sender: UIButton) {
        loadJSONProfessors()
    }
    func loadJSONProfessors(){
        var professors: [Professor]!
        var departments: [Department]!
        var courses: [Course]!
        
        //Runs on seperate thread
        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        dispatch_async(backgroundQueue, {
            
            //This is run on the background queue
            DataManager.getProfessorsFromProfsquireWithSuccess { (professorsData) -> Void in
                //Retreive the managedObjectContext from AppDelegate
                let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
                
                //For clocking runtime of parsing
                let startTime = CFAbsoluteTimeGetCurrent()
                
                println("== Starting FULL/FRESH professor data JSON parsing... ==")
                let json = JSON(data: professorsData)
                for index in 0...json.count-1 { //goes through every line of json
                    if let id = json[index]["id"].number {
                        print("    - Parsed ID from JSON: \(id). Creating new professor entity ")
                        let newProfItem = NSEntityDescription.insertNewObjectForEntityForName("Professor", inManagedObjectContext: managedObjectContext!) as! Professor
                        newProfItem.id = id
                        if let name = json[index]["name"].string {
                            println("with name " + name + ".")
                            newProfItem.name = name
                        }
                        //need to assign professor a 'Personality'
                    }
                }
                
                //Saves the managedObjectContext
                var error : NSError? = nil
                if !managedObjectContext!.save(&error) {
                    NSLog("Unresolved error \(error), \(error!.userInfo)")
                    abort()
                }
                
                //Benchmark of parsing
                println("== Professor data parsing and storing took \(CFAbsoluteTimeGetCurrent() - startTime) s. ==\n")
                
                DataManager.getCoursesFromProfsquireWithSuccess { (coursesData) -> Void in
                    //Retreive the managedObjectContext from AppDelegate
                    let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext

                    //For clocking runtime of parsing
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    //Packaged textfield with english names of DepartmentNames for user readability is read in here from bundle...
                    var departmentNames: [String] = [] // put into this variable
                    let path = NSBundle.mainBundle().pathForResource("DepartmentNames", ofType: "txt")
                    if let text = String(contentsOfFile: path!, encoding: NSUTF8StringEncoding, error: nil) {
                        var placeholderName = ""
                        for character in text {
                            if (character != "\n") {
                                placeholderName.append(character)
                            } else {
                                departmentNames.append(placeholderName)
                                placeholderName = ""
                            }
                        }
                    }
                    
                    println("== Starting FULL/FRESH course data JSON parsing... ==")
                    let json = JSON(data: coursesData)
                    for index in 0...json.count-1 {
                        var newDeptItem: Department!
                        if var parsedDepartmentName = json[index]["department"].string {
                            
                            //The next 'for' statement tries to check if there is a better way to spell the department name from constant list
                            for name in departmentNames {
                                if name.lowercaseString.rangeOfString(parsedDepartmentName.lowercaseString) != nil {
                                    parsedDepartmentName = name
                                    break
                                }
                            }
                            
                            let fetchRequest = NSFetchRequest(entityName: "Department")
                            fetchRequest.predicate = NSPredicate(format: "title == %@", parsedDepartmentName)
                            if let fetchResults: [Department]? = managedObjectContext!.executeFetchRequest(fetchRequest, error: nil) as? [Department] {
                                if fetchResults!.count != 0 {
                                    newDeptItem = fetchResults![0]
                                    println("        - Found another department of name " + parsedDepartmentName + " in MOC")
                                } else {
                                    newDeptItem = NSEntityDescription.insertNewObjectForEntityForName("Department", inManagedObjectContext: managedObjectContext!) as! Department
                                    newDeptItem.title = parsedDepartmentName
                                    println("    - Parsed unique department from JSON: " + parsedDepartmentName + ".")
                                }
                            }
                        }
                        
                        let newGDItem = NSEntityDescription.insertNewObjectForEntityForName("GradeDistribution", inManagedObjectContext: managedObjectContext!) as! GradeDistribution
                        if let a = json[index]["a"].number {
                            newGDItem.a = a
                        } else {
                            newGDItem.a = 0
                        }
                        if let b = json[index]["b"].number {
                            newGDItem.b = b
                        } else {
                            newGDItem.b = 0
                        }
                        if let c = json[index]["c"].number {
                            newGDItem.c = c
                        } else {
                            newGDItem.c = 0
                        }
                        if let d = json[index]["d"].number {
                            newGDItem.d = d
                        } else {
                            newGDItem.d = 0
                        }
                        if let f = json[index]["f"].number {
                            newGDItem.f = f
                        } else {
                            newGDItem.f = 0
                        }
                        if let w = json[index]["w"].number {
                            newGDItem.w = w
                        } else {
                            newGDItem.w = 0
                        }
                        
                        newGDItem.total = Int(newGDItem.a) + Int(newGDItem.b) + Int(newGDItem.c) + Int(newGDItem.d) + Int(newGDItem.f)
                        newGDItem.avgGPA = Double(newGDItem.a)/Double(newGDItem.total)*4 + Double(newGDItem.b)/Double(newGDItem.total)*3.5 + Double(newGDItem.c)/Double(newGDItem.total)*3 + Double(newGDItem.d)/Double(newGDItem.total)*2.5 + Double(newGDItem.f)/Double(newGDItem.total)*2
                        
                        println("== GRADE DISTRIBUTION LAYOUT - A: \(Int(newGDItem.a)). B: \(Int(newGDItem.b)). C: \(Int(newGDItem.c)). D: \(Int(newGDItem.d)). F: \(Int(newGDItem.f)). Total: \(newGDItem.total). AvgGPA: \(newGDItem.avgGPA)")
                        
                        let newCrsItem = NSEntityDescription.insertNewObjectForEntityForName("Course", inManagedObjectContext: managedObjectContext!) as! Course
                        newCrsItem.department = newDeptItem
                        newCrsItem.grade_distribution = newGDItem
                        if let prof_id = json[index]["professor_id"].number {
                            let fetchRequest = NSFetchRequest(entityName: "Professor")
                            fetchRequest.predicate = NSPredicate(format: "id == \(prof_id)")
                            if let fetchResults = managedObjectContext!.executeFetchRequest(fetchRequest, error: nil) as? [Professor] {
                                if fetchResults.count != 0 {
                                    newCrsItem.professor = fetchResults[0]
                                } else {
                                    println("Couldn't find professor with id \(prof_id)")
                                }
                            }
                        }
                        if let crs_id = json[index]["id"].number {
                            newCrsItem.id = crs_id
                        }
                        if let course_name = json[index]["course"].string {
                            newCrsItem.title = course_name
                            println("            - Saving course " + course_name + ".")
                        }
                        if let semester = json[index]["semester"].string {
                            newCrsItem.semester = semester
                        }
                        if let yr = json[index]["year"].number {
                            newCrsItem.year = yr
                        }
                        if let section = json[index]["section"].number {
                            newCrsItem.section = section
                        }
                    }
                    println("== Course data parsing and storing took \(CFAbsoluteTimeGetCurrent() - startTime) s. ==\n")
                    
                    //Saving MOC
                    var error : NSError? = nil
                    if !managedObjectContext!.save(&error) {
                        NSLog("Unresolved error \(error), \(error!.userInfo)")
                        abort()
                    }
                }
            }

            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                println("This is run on the main queue, after the previous code in outer block")
                
            })
        })
        
    }
}